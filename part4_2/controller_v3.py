import subprocess
import time
import psutil
import docker
from docker.errors import NotFound, APIError
from scheduler_logger import SchedulerLogger, Job

# -- Configuration -----------------------------------------------------------
TOTAL_CORES = [0, 1, 2, 3]
MEMCACHED_SERVICE = "memcached"

# Hysteresis thresholds for memcached core scaling
CPU_THRESHOLD_UP   = 60
CPU_THRESHOLD_DOWN = 30

#POLL_INTERVAL = 0.1

# Per-job thread tuning
JOB_THREADS = {
    Job.BLACKSCHOLES: 3,
    Job.CANNEAL:     3,
    Job.DEDUP:       3,
    Job.FERRET:      3,
    Job.FREQMINE:    3,
    Job.RADIX:       2,
    Job.VIPS:        3,
}

# Ordered groups to launch sequentially
JOB_GROUPS = [
    [Job.BLACKSCHOLES, Job.CANNEAL, Job.DEDUP],
    [Job.VIPS, Job.RADIX, Job.FERRET],
    [Job.FREQMINE]
]

# Helpers
def run(cmd: str) -> subprocess.CompletedProcess:
    """Run a shell command and return the CompletedProcess."""
    #print(f"[CMD] {cmd}")
    return subprocess.run(cmd, shell=True, capture_output=True, text=True)


def get_memcached_pid() -> int:
    """Get the PID of the memcached service."""
    pid = int(run(f"pidof {MEMCACHED_SERVICE}").stdout.strip())
    #print(f"[INFO] memcached PID={pid}")
    return pid


def set_affinity(pid: int, cores: list[int]) -> None:
    """Bind a process to a set of CPU cores."""
    core_str = ",".join(map(str, cores))
    run(f"sudo taskset -a -cp {core_str} {pid}")
    #print(f"[INFO] Set PID {pid} affinity to {core_str}")


def get_memcached_needed_cores(pid: int, current_cores: list[int]) -> int:
    """
    Return required core count (1 or 2) based on memcached CPU% usage
    and hysteresis thresholds:
      - If on 1 core and usage > CPU_THRESHOLD_UP, scale up to 2 cores.
      - If on 2 cores and usage < CPU_THRESHOLD_DOWN, scale down to 1 core.
      - Otherwise, keep the current allocation.
    """
    usage = psutil.Process(pid).cpu_percent(interval=1)
    #print(f"[INFO] memcached CPU%: {usage}")

    if len(current_cores) == 1:
        # currently on 1 core: maybe scale up
        return 2 if usage > CPU_THRESHOLD_UP else 1
    else:
        # currently on 2 (or more) cores: maybe scale down
        return 1 if usage < CPU_THRESHOLD_DOWN else 2


def launch_batch_job(
    client: docker.DockerClient,
    job: Job,
    cores: list[int],
) -> docker.models.containers.Container:
    """Launch a batch job, oversubscribing threads to provided cores."""
    prefix = "splash2x" if job == Job.RADIX else "parsec"
    image = f"anakli/cca:{prefix}_{job.value}"
    threads = JOB_THREADS.get(job, len(cores))
    cmd = f"./run -a run -S {prefix} -p {job.value} -i native -n {threads}"

    # clean up any old container
    try:
        old = client.containers.get(job.value)
        old.remove(force=True)
        #print(f"[INFO] Removed leftover '{job.value}' container")
    except NotFound:
        pass

    try:
        container = client.containers.run(
            image,
            name=job.value,
            command=cmd,
            cpuset_cpus=",".join(map(str, cores)),
            detach=True,
            remove=False,
        )
    except APIError as e:
        #print(f"[ERROR] launching {job.value}: {e}")
        raise

    logger.job_start(job, cores, threads)
    #print(f"[INFO] Launched {job.value} on {cores} ({threads} threads)")
    return container


def update_batch_affinity(
    client: docker.DockerClient,
    free_cores: list[int],
) -> None:
    """Reapply affinity for all running batch containers to new free_cores."""
    core_str = ",".join(map(str, free_cores))
    for c in client.containers.list():
        enum_job = next((j for j in JOB_THREADS if j.value == c.name), None)
        if enum_job:
            c.update(cpuset_cpus=core_str)
            logger.update_cores(enum_job, free_cores)
            #print(f"[INFO] Updated {enum_job.value} -> {free_cores}")


# Main control loop
if __name__ == "__main__":
    logger = SchedulerLogger()
    client = docker.from_env()

    # 1) get memcached process id and pin it to 2 cores initially
    memc_pid = get_memcached_pid()
    current_mem_cores = TOTAL_CORES[:2]
    set_affinity(memc_pid, current_mem_cores)
    logger.job_start(Job.MEMCACHED, current_mem_cores, len(current_mem_cores))
    time.sleep(5)

    next_group = 0
    active = []  # list of (Job, Container)

    try:
        while True:
            # A) adjust memcached cores if needed (with hysteresis)
            needed = get_memcached_needed_cores(memc_pid, current_mem_cores)
            if needed != len(current_mem_cores):
                new_mem = TOTAL_CORES[:needed]
                set_affinity(memc_pid, new_mem)
                logger.update_cores(Job.MEMCACHED, new_mem)
                free = [c for c in TOTAL_CORES if c not in new_mem]
                update_batch_affinity(client, free)
                current_mem_cores = new_mem

            # B) reap finished batch containers
            still_active = []
            for job, cont in active:
                try:
                    cont.reload()
                except NotFound:
                    logger.job_end(job)
                    #print(f"[INFO] {job.value} container missing; marking complete")
                    continue
                if cont.status != "running":
                    exit_code = cont.attrs['State']['ExitCode']
                    logger.job_end(job)
                    #print(f"[INFO] {job.value} exited with code {exit_code}")
                    cont.remove()
                else:
                    still_active.append((job, cont))
            active = still_active

            # C) if no batch active and more groups remain, launch next group
            if not active and next_group < len(JOB_GROUPS):
                group = JOB_GROUPS[next_group]
                free = [c for c in TOTAL_CORES if c not in current_mem_cores]
                for job in group:
                    cont = launch_batch_job(client, job, free)
                    active.append((job, cont))
                next_group += 1

            # D) exit when all groups done and no active containers
            if next_group >= len(JOB_GROUPS) and not active:
                print("[INFO] All batch groups completed")
                break

            #sleep to avoid a tight busy loop
            # time.sleep(POLL_INTERVAL)

    except KeyboardInterrupt:
        print("[INFO] Controller interrupted by user")

    finally:
        # ensure cleanup and logging
        for job, _ in active:
            logger.job_end(job)
        logger.job_end(Job.MEMCACHED)
        logger.end()
