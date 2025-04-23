import psutil
import sys
import time
pid = int(sys.argv[1])
process = psutil.Process(pid)
interval = 5
count = 44
i,j = 0,0
try :
    while True:
        j=0;
        while j< 2:
            usage = process.cpu_percent(2.5)
            ts = time.time_ns()
            print(f"{usage} {ts}")
            j = j+ 1
            time.sleep(2.5)
        print()
        i = i +1
except :
    pass
