extends RefCounted

const DEFAULT_URL := "https://arthritis-inquiry-variance-handheld.trycloudflare.com"
const RETIRED_URLS := [
	"https://mardi-interest-postal-memorabilia.trycloudflare.com",
	"https://bedrooms-value-expand-arch.trycloudflare.com",
]


static func resolve(url: String) -> String:
	var cleaned := url.strip_edges().rstrip("/")
	return DEFAULT_URL if cleaned.is_empty() or cleaned in RETIRED_URLS else cleaned
