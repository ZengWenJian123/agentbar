import Foundation

public enum PrivacyScrubber {
    public static func scrub(_ value: String) -> String {
        var result = value
        result = replace(
            pattern: #"(?i)(bearer\s+)[^\s,;"]+"#,
            in: result,
            with: "$1[redacted]"
        )
        result = replace(
            pattern: #"sk-[A-Za-z0-9_\-]+"#,
            in: result,
            with: "sk-[redacted]"
        )
        result = replace(
            pattern: #"([?&](?:sso_access_token|sso_client_id)=)[^&\s]+"#,
            in: result,
            with: "$1[redacted]"
        )
        return result
    }

    private static func replace(pattern: String, in value: String, with template: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return value
        }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        return regex.stringByReplacingMatches(in: value, range: range, withTemplate: template)
    }
}
