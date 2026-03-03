import CoreMedia

extension CMTime {
    var displayString: String {
        guard isValid, !isIndefinite else { return "0:00" }
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    var shortDisplayString: String {
        guard isValid, !isIndefinite else { return "0s" }
        let s = seconds
        if s < 60 {
            return String(format: "%.1fs", s)
        }
        return displayString
    }
}
