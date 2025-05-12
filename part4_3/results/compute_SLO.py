import datetime

def parse_timestamp(line):
    """Extract and convert ISO 8601 timestamp to datetime object."""
    timestamp_str = line.split()[0]
    return datetime.datetime.fromisoformat(timestamp_str)

def extract_active_window(jobs_file_path):
    """Returns the earliest job start and latest job end timestamps."""
    start_time = None
    end_time = None
    with open(jobs_file_path, 'r') as f:
        for line in f:
            if "start" in line and "scheduler" not in line and "memcached" not in line:
                ts = parse_timestamp(line)
                if start_time is None or ts < start_time:
                    start_time = ts
            elif "end" in line and "scheduler" not in line and "memcached" not in line:
                ts = parse_timestamp(line)
                if end_time is None or ts > end_time:
                    end_time = ts
    return start_time, end_time

def compute_slo_violation_rate(clean_file_path, jobs_file_path, interval_seconds=5):
    """Computes the SLO violation rate from clean_X.txt and jobs_X.txt."""
    # Determine job activity time range
    job_start, job_end = extract_active_window(jobs_file_path)

    if job_start is None or job_end is None:
        raise ValueError("No job start/end timestamps found in jobs file.")

    total_points = 0
    violations = 0

    # Start timestamp aligned with the first clean data point
    current_time = job_start

    with open(clean_file_path, 'r') as f:
        for line in f:
            if line.startswith("read"):
                if job_start <= current_time <= job_end:
                    parts = line.split()
                    p95 = float(parts[12])
                    total_points += 1
                    if p95 > 800:
                        violations += 1
                current_time += datetime.timedelta(seconds=interval_seconds)

    if total_points == 0:
        return 0.0

    print(f"violations: {violations}, total points: {total_points}")

    return violations / total_points

# Example usage:
rate = compute_slo_violation_rate("clean_4.txt", "jobs_4.txt")
print(f"SLO violation rate: {rate:.2%}")

