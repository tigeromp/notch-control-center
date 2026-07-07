import Foundation

enum NewsRegionCatalog {
    static func displayName(for countryCode: String) -> String {
        switch countryCode.uppercased() {
        case "US": return "United States"
        case "GB": return "United Kingdom"
        case "CA": return "Canada"
        case "AU": return "Australia"
        case "DE": return "Germany"
        case "FR": return "France"
        case "IN": return "India"
        case "IE": return "Ireland"
        case "NZ": return "New Zealand"
        case "JP": return "Japan"
        case "MX": return "Mexico"
        case "BR": return "Brazil"
        default: return countryCode.uppercased()
        }
    }

    static func feeds(for countryCode: String) -> [URL] {
        switch countryCode.uppercased() {
        case "US":
            return urls(
                "https://feeds.npr.org/1001/rss.xml",
                "https://news.google.com/rss?hl=en-US&gl=US&ceid=US:en"
            )
        case "GB":
            return urls(
                "https://feeds.bbci.co.uk/news/rss.xml",
                "https://feeds.bbci.co.uk/news/uk/rss.xml"
            )
        case "CA":
            return urls(
                "https://www.cbc.ca/cmlink/rss-topstories",
                "https://news.google.com/rss?hl=en-CA&gl=CA&ceid=CA:en"
            )
        case "AU":
            return urls(
                "https://www.abc.net.au/news/feed/51120/rss.xml",
                "https://news.google.com/rss?hl=en-AU&gl=AU&ceid=AU:en"
            )
        case "DE":
            return urls(
                "https://news.google.com/rss?hl=de-DE&gl=DE&ceid=DE:de",
                "https://rss.dw.com/rdf/rss-en-top"
            )
        case "FR":
            return urls(
                "https://www.france24.com/en/rss",
                "https://news.google.com/rss?hl=fr-FR&gl=FR&ceid=FR:fr"
            )
        case "IN":
            return urls(
                "https://news.google.com/rss?hl=en-IN&gl=IN&ceid=IN:en",
                "https://timesofindia.indiatimes.com/rssfeedstopstories.cms"
            )
        case "IE":
            return urls(
                "https://www.rte.ie/news/rss/news-headlines.xml",
                "https://news.google.com/rss?hl=en-IE&gl=IE&ceid=IE:en"
            )
        case "NZ":
            return urls(
                "https://www.rnz.co.nz/rss/national",
                "https://news.google.com/rss?hl=en-NZ&gl=NZ&ceid=NZ:en"
            )
        case "JP":
            return urls(
                "https://news.google.com/rss?hl=en-JP&gl=JP&ceid=JP:en",
                "https://www.japantimes.co.jp/feed/"
            )
        case "MX":
            return urls(
                "https://news.google.com/rss?hl=es-MX&gl=MX&ceid=MX:es",
                "https://www.eluniversal.com.mx/rss.xml"
            )
        case "BR":
            return urls(
                "https://news.google.com/rss?hl=pt-BR&gl=BR&ceid=BR:pt-419",
                "https://agenciabrasil.ebc.com.br/rss/feed.xml"
            )
        default:
            return urls(googleNewsURL(countryCode: countryCode))
        }
    }

    private static func googleNewsURL(countryCode: String) -> String {
        let cc = countryCode.uppercased()
        return "https://news.google.com/rss?hl=en-\(cc)&gl=\(cc)&ceid=\(cc):en"
    }

    private static func urls(_ strings: String...) -> [URL] {
        strings.compactMap { URL(string: $0) }
    }
}
