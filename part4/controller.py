import subprocess
import time
import psutil
from scheduler_logger import SchedulerLogger, Job

# -- config -- 

MEMCACHED_PID = None 
MEMCACHED_THREAD_COUNT = 2 
MEMCACHED_INITIAL_CORES = [0] 
MEMCACHED_INITIAL_CORES_STR = [str(core) for core in MEMCACHED_INITIAL_CORES] 
BATCH_JOBS = [
    Job.BLACKSCHOLES,
    Job.CANNEAL,
    Job.DEDUP,
    Job.FERRET,
    Job.FREQMINE,
    Job.RADIX,
    Job.VIPS,
] 
AVAILABLE_CORES = [0, 1, 2, 3]
BATCH_CORES = [2, 3] 
BATCH_THREADS = 2 

# -- end config -- 

# -- helpers -- 

def run(cmd) -> subprocess.CompletedProcess:
    """
    Run a shell command and return the CompletedProcess object
    """
    print(f"[MP_CMD] {cmd}")
    #subprocess runs shells commands (so terminal commands from inside python)
    #the CompletedProcess object contains logs and return codes
    return subprocess.run(cmd, shell=True, capture_output=True, text=True)


def launch_memcached(cores, threads) -> None:
    """
    Launch memcached with the specified number of threads and set CPU affinity
    """
    global MEMCACHED_PID #update MEMCACHED_PID globally 
    run(f"sudo systemctl stop memcached") #stop memcached in case it's already running 
    run(f"sudo sed -i 's/-t .*/-t {threads}/' /etc/memcached.conf")
    run(f"sudo systemctl start memcached")
    time.sleep(1)
    pid_result = run("pidof memcached")
    MEMCACHED_PID = pid_result.stdout.strip()
    set_affinity(MEMCACHED_PID, cores) 
    print(f"[MP_INFO] Memcached started with PID {MEMCACHED_PID}") 


def set_affinity(pid, cores) -> None:
    """
    Set CPU affinity for a given PID
    """
    core_str = ",".join(map(str, cores))
    run(f"sudo taskset -a -cp {core_str} {pid}") 
    print(f"[MP_INFO] Set PID {pid} affinity to {core_str}") 

def launch_batch_job(job: Job, cores: list[int], threads: int) -> None: 
    """
    Launch a batch job with the specified number of threads and set CPU affinity
    """
    core_str = ",".join(map(str, cores))
    image = f"anakli/cca:parsec_{job.value}" 
    cmd = f'docker run --cpuset-cpus="{core_str}" -d --rm --name {job.value} ' \
          f'{image} ./run -a run -S parsec -p {job.value} -i native -n {threads}'
    run(cmd)
    logger.job_start(job, [str(core) for core in cores], threads)

def monitor_cpu(interval=5) -> list[float]:
    """
    Monitor CPU usage across all cores.
    """
    #return CPU usage
    return psutil.cpu_percent(percpu=True, interval=interval)

def is_running(job: Job) -> bool: 
    result = run(f"docker ps -q -f name={job.value}")
    return result.stdout.strip() != ""


# -- end helpers -- 


# -- controller -- 

if __name__ == "__main__":
    logger = SchedulerLogger()
    job_running = False
    current_job = None
    job_index = 0

    try:
        #launch memcached 
        logger.job_start(Job.MEMCACHED, MEMCACHED_INITIAL_CORES_STR, MEMCACHED_THREAD_COUNT)
        launch_memcached(MEMCACHED_INITIAL_CORES, MEMCACHED_THREAD_COUNT)
        time.sleep(10)

        #main loop (with controller logic) 
        # TODO: implement actual scheduling policy 
        # this one is a dummy 

        while True:
            cpu_util = monitor_cpu()
            print(f"[MP_INFO] CPU usage: {cpu_util}")

            if job_running: 
                if not is_running(current_job):
                    logger.job_end(current_job)
                    job_running = False 

            else : 
                if job_index < len(BATCH_JOBS):
                    current_job = BATCH_JOBS[job_index]
                    launch_batch_job(current_job, BATCH_CORES, BATCH_THREADS)
                    job_running = True 
                    job_index += 1 
                else : 
                    print("[MP_INFO] all jobs completed") 
                    break

           
            time.sleep(5)  #check every 5s

    except KeyboardInterrupt:
        print("\n[MP_INFO] Controller stopped by user.")

    finally:
        logger.job_end(Job.MEMCACHED)
        logger.end() 


# -- end controller -- 

