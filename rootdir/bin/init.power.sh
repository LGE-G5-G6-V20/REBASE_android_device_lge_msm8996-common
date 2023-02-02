#!/vendor/bin/sh

################################################################################
# local definitions

soc_revision=`cat /sys/devices/soc0/revision`
soc_machine=`cat /sys/devices/soc0/machine`

################################################################################

################################################################################
# helper functions to allow Android init like script

function write() {
    echo -n $2 > $1
}

function copy() {
    cat $1 > $2
}

################################################################################

# disable thermal hotplug to switch governor
write /sys/module/msm_thermal/core_control/enabled 0

# bring back main cores CPU 0,2
write /sys/devices/system/cpu/cpu0/online 1
write /sys/devices/system/cpu/cpu2/online 1

# configure governor settings for little cluster
echo "schedutil" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
echo 500 > /sys/devices/system/cpu/cpu0/cpufreq/schedutil/up_rate_limit_us
echo 20000 > /sys/devices/system/cpu/cpu0/cpufreq/schedutil/down_rate_limit_us 20000
        
# configure governor settings for big cluster
echo "schedutil" > /sys/devices/system/cpu/cpu2/cpufreq/scaling_governor
echo 500 > /sys/devices/system/cpu/cpu2/cpufreq/schedutil/up_rate_limit_us
echo 20000 > /sys/devices/system/cpu/cpu2/cpufreq/schedutil/down_rate_limit_us 20000

# re-enable thermal hotplug
write /sys/module/msm_thermal/core_control/enabled 1

# Setting b.L scheduler parameters
write /proc/sys/kernel/sched_migration_fixup 1
write /proc/sys/kernel/sched_upmigrate 95
write /proc/sys/kernel/sched_downmigrate 90
write /proc/sys/kernel/sched_freq_inc_notify 400000
write /proc/sys/kernel/sched_freq_dec_notify 400000
write /proc/sys/kernel/sched_spill_nr_run 3
write /proc/sys/kernel/sched_init_task_load 100

# Update DVR cpusets to boot-time values.
write /dev/cpuset/kernel/cpus 0-3
write /dev/cpuset/system/cpus 0-3
write /dev/cpuset/system/performance/cpus 0-3
write /dev/cpuset/system/background/cpus 0-3
write /dev/cpuset/system/cpus 0-3
write /dev/cpuset/application/cpus 0-3
write /dev/cpuset/application/performance/cpus 0-3
write /dev/cpuset/application/background/cpus 0-3
write /dev/cpuset/application/cpus 0-3

# Enable bus-dcvs
for cpubw in /sys/class/devfreq/*qcom,cpubw* ; do
    write $cpubw/governor "bw_hwmon"
    write $cpubw/polling_interval 50
    write $cpubw/min_freq 1525
    write $cpubw/bw_hwmon/mbps_zones "1525 5195 11863 13763"
    write $cpubw/bw_hwmon/sample_ms 4
    write $cpubw/bw_hwmon/io_percent 34
    write $cpubw/bw_hwmon/hist_memory 20
    write $cpubw/bw_hwmon/hyst_length 10
    write $cpubw/bw_hwmon/low_power_ceil_mbps 0
    write $cpubw/bw_hwmon/low_power_io_percent 34
    write $cpubw/bw_hwmon/low_power_delay 20
    write $cpubw/bw_hwmon/guard_band_mbps 0
    write $cpubw/bw_hwmon/up_scale 250
    write $cpubw/bw_hwmon/idle_mbps 1600
done

for memlat in /sys/class/devfreq/*qcom,memlat-cpu* ; do
    write $memlat/governor "mem_latency"
    write $memlat/polling_interval 10
done

# Drop msm8996pro's base GPU clock to 133Mhz from 214MHz
if [ "$soc_machine" == "MSM8996pro" ]; then
	write /sys/class/kgsl/kgsl-3d0/default_pwrlevel 7
fi

# This doesn't affect msm8996pro since it's revisions only go to 1.1
if [ "$soc_revision" == "2.0" ]; then
  #Disable suspend for v2.0
  write /sys/power/wake_lock pwr_dbg
elif [ "$soc_revision" == "2.1" ]; then
  # Enable C4.D4.E4.M3 LPM modes
  # Disable D3 state
  write /sys/module/lpm_levels/system/pwr/pwr-l2-gdhs/idle_enabled 0
  write /sys/module/lpm_levels/system/perf/perf-l2-gdhs/idle_enabled 0
  # Disable DEF-FPC mode
  write /sys/module/lpm_levels/system/pwr/cpu0/fpc-def/idle_enabled N
  write /sys/module/lpm_levels/system/pwr/cpu1/fpc-def/idle_enabled N
  write /sys/module/lpm_levels/system/perf/cpu2/fpc-def/idle_enabled N
  write /sys/module/lpm_levels/system/perf/cpu3/fpc-def/idle_enabled N
fi

# Enable all LPMs by default
# This will enable C4, D4, D3, E4 and M3 LPMs
write /sys/module/lpm_levels/parameters/sleep_disabled N

# Signal perfd that boot has completed
setprop sys.post_boot.parsed 1
