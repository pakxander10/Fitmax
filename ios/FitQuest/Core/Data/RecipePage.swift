import Foundation

/// What a recipe web page says about itself: its dish, and its nutrition per serving when it publishes any.
struct RecipePage: Equatable {
    var name: String
    var kcal: Int?
    var protein: Int?

    /// Reads the page's schema.org Recipe data, which most recipe sites embed; failing that, its title.
    static func parse(html: String) -> RecipePage? {
        for block in captures(#"<script[^>]*application/ld\+json[^>]*>(.*?)</script>"#, in: html) {
            guard let json = try? JSONSerialization.jsonObject(with: Data(block.utf8)),
                  let recipe = recipe(in: json), let name = recipe["name"] as? String, !name.isEmpty else { continue }
            let nutrition = recipe["nutrition"] as? [String: Any]
            return RecipePage(name: name, kcal: amount(nutrition?["calories"]), protein: amount(nutrition?["proteinContent"]))
        }
        guard let title = captures("<title[^>]*>(.*?)</title>", in: html).first.map(unescape), !title.isEmpty else { return nil }
        return RecipePage(name: title)
    }

    /// True when at least half the words of the dish's name appear in the page's name.
    /// This is what tells the right recipe from a "not found" page or a redirect to the home page.
    func isAbout(_ dish: String) -> Bool {
        let wanted = Self.words(dish), found = Self.words(name)
        guard !wanted.isEmpty else { return false }
        return wanted.intersection(found).count * 2 >= wanted.count
    }

    // MARK: Private

    /// The first schema.org Recipe object anywhere in a JSON-LD value, including inside `@graph` and lists.
    private static func recipe(in json: Any) -> [String: Any]? {
        if let list = json as? [Any] { return list.lazy.compactMap(recipe).first }
        guard let object = json as? [String: Any] else { return nil }
        let types = (object["@type"] as? [String]) ?? (object["@type"] as? String).map { [$0] } ?? []
        if types.contains("Recipe") { return object }
        return object.values.lazy.compactMap(recipe).first
    }

    /// "386 kcal", "12.6g" or a bare number, as a whole number above zero. The text must start with the number.
    private static func amount(_ value: Any?) -> Int? {
        let number: Double? = if let value = value as? NSNumber {
            value.doubleValue
        } else {
            (value as? String).flatMap { captures(#"^\s*(\d+(?:\.\d+)?)"#, in: $0).first }.flatMap(Double.init)
        }
        guard let number, number > 0, number < 10_000 else { return nil }
        return Int(number.rounded())
    }

    /// Lowercased words of three letters or more, minus filler and a plural "s".
    private static func words(_ text: String) -> Set<String> {
        let filler: Set<String> = ["and", "with", "the", "for", "recipe", "recipes"]
        let words = text.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init)
        return Set(words.filter { $0.count >= 3 && !filler.contains($0) }.map { $0.hasSuffix("s") ? String($0.dropLast()) : $0 })
    }

    private static func captures(_ pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else { return [] }
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap {
            Range($0.range(at: 1), in: text).map { String(text[$0]) }
        }
    }

    private static func unescape(_ title: String) -> String {
        [("&amp;", "&"), ("&#39;", "'"), ("&#039;", "'"), ("&quot;", "\""), ("&#8217;", "’"), ("&#8211;", "–")]
            .reduce(title) { $0.replacingOccurrences(of: $1.0, with: $1.1) }
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// What opening a recipe link showed.
enum LinkCheck: Equatable {
    /// The page loaded and is about the dish.
    case confirmed(RecipePage)
    /// The site answered but turned the app away, as sites behind a bot check do. It may well open in a browser.
    case blocked
    /// Not found, unreachable, insecure, or about something else.
    case missing
}

/// Opens a recipe link to confirm it is live and really about the dish it is meant to be.
struct RecipeLinkChecker {
    var session: URLSession = .shared
    var timeout: TimeInterval = 8

    /// Recipe sites often turn away anything that does not look like a browser.
    private static let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"

    /// Statuses a site uses to refuse a visitor it takes for a script.
    private static let refusals: Set<Int> = [401, 403, 429]

    /// The page at `url`, or nil unless it loads over HTTPS and is about `dish`.
    func page(at url: URL, about dish: String) async -> RecipePage? {
        if case .confirmed(let page) = await check(url, about: dish) { return page }
        return nil
    }

    func check(_ url: URL, about dish: String) async -> LinkCheck {
        guard url.scheme?.lowercased() == "https", url.host?.contains(".") == true else { return .missing }
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("text/html", forHTTPHeaderField: "Accept")
        guard let (data, response) = try? await session.data(for: request) else { return .missing }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if Self.refusals.contains(status) { return .blocked }
        guard status == 200, let page = RecipePage.parse(html: String(decoding: data, as: UTF8.self)),
              page.isAbout(dish) else { return .missing }
        return .confirmed(page)
    }
}
