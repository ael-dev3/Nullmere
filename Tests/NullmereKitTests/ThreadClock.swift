import Foundation

/// This thread's own CPU time, in milliseconds: what a measured piece of
/// work costs, unstretched by others' work on a shared CI runner.
enum ThreadClock {
    static func milliseconds() -> Double {
        var time = timespec()
        clock_gettime(CLOCK_THREAD_CPUTIME_ID, &time)
        return Double(time.tv_sec) * 1000 + Double(time.tv_nsec) / 1e6
    }
}
