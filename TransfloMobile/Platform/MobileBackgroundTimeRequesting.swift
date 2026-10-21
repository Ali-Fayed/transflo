/// Asks the system for time to finish running jobs after the user switches away.
protocol MobileBackgroundTimeRequesting: AnyObject {
    func update(jobsRunning: Bool)
}
