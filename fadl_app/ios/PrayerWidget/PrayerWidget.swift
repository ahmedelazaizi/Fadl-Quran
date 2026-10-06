import SwiftUI
import WidgetKit

/// Shared with the app (AppDelegate), which saves the offline prayer
/// calendar computed in Dart (lib/core/prayer_widget_schedule.dart).
let fadlAppGroup = "group.com.fadl.fadl"
let fadlScheduleKey = "fadl.prayer.schedule"

private extension Color {
  static let fadlGreen = Color(red: 1 / 255, green: 52 / 255, blue: 40 / 255)
  static let fadlGold = Color(red: 199 / 255, green: 167 / 255, blue: 92 / 255)
}

struct Prayer {
  let at: Date
  let name: String
  let local: String
}

/// The saved calendar: absolute prayer instants, plus Hijri labels keyed by
/// the date in the selected city's time zone.
struct PrayerSchedule {
  let prayers: [Prayer]
  let hijri: [String: String]
  let calendar: Calendar
  private let dayFormatter: DateFormatter

  init(prayers: [Prayer], hijri: [String: String], timeZone: TimeZone) {
    self.prayers = prayers.sorted { $0.at < $1.at }
    self.hijri = hijri
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    self.calendar = calendar
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = timeZone
    formatter.dateFormat = "yyyy-MM-dd"
    dayFormatter = formatter
  }

  static func load() -> PrayerSchedule? {
    guard
      let json = UserDefaults(suiteName: fadlAppGroup)?.string(forKey: fadlScheduleKey),
      let data = json.data(using: .utf8),
      let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
      let items = root["prayers"] as? [[String: Any]]
    else { return nil }
    let prayers: [Prayer] = items.compactMap { item in
      guard let millis = (item["at"] as? NSNumber)?.doubleValue,
        let name = item["name"] as? String
      else { return nil }
      return Prayer(
        at: Date(timeIntervalSince1970: millis / 1000),
        name: name,
        local: item["local"] as? String ?? "")
    }
    let zone = (root["timezone"] as? String).flatMap(TimeZone.init(identifier:)) ?? .current
    return PrayerSchedule(
      prayers: prayers, hijri: root["dates"] as? [String: String] ?? [:], timeZone: zone)
  }

  func dayKey(_ date: Date) -> String { dayFormatter.string(from: date) }

  func entry(at date: Date) -> PrayerEntry {
    let key = dayKey(date)
    return PrayerEntry(
      date: date,
      next: prayers.first { $0.at > date },
      today: prayers.filter { dayKey($0.at) == key },
      hijri: hijri[key] ?? "")
  }
}

struct PrayerEntry: TimelineEntry {
  let date: Date
  let next: Prayer?
  let today: [Prayer]
  let hijri: String

  static func empty(_ date: Date) -> PrayerEntry {
    PrayerEntry(date: date, next: nil, today: [], hijri: "")
  }

  static var sample: PrayerEntry {
    let now = Date()
    let names = ["الفجر", "الظهر", "العصر", "المغرب", "العشاء"]
    let times = ["04:45", "11:50", "15:15", "17:40", "19:10"]
    let today = names.indices.map {
      Prayer(at: now.addingTimeInterval(Double($0 - 1) * 3 * 3600), name: names[$0], local: times[$0])
    }
    return PrayerEntry(date: now, next: today[2], today: today, hijri: "١٤ ربيع الآخر ١٤٤٨ هـ")
  }
}

struct PrayerProvider: TimelineProvider {
  func placeholder(in context: Context) -> PrayerEntry { .sample }

  func getSnapshot(in context: Context, completion: @escaping (PrayerEntry) -> Void) {
    if context.isPreview {
      completion(.sample)
    } else {
      completion(PrayerSchedule.load()?.entry(at: Date()) ?? .empty(Date()))
    }
  }

  /// An entry now, at each of the next prayers (when "next" moves on) and at
  /// each midnight in between (when the Hijri date and the day list change).
  func getTimeline(in context: Context, completion: @escaping (Timeline<PrayerEntry>) -> Void) {
    let now = Date()
    guard let schedule = PrayerSchedule.load() else {
      // The app saves a calendar and reloads the widget once a city is set.
      completion(Timeline(entries: [.empty(now)], policy: .never))
      return
    }
    let upcoming = schedule.prayers.filter { $0.at > now }.prefix(12).map(\.at)
    guard let horizon = upcoming.last else {
      completion(Timeline(entries: [schedule.entry(at: now)], policy: .never))
      return
    }
    var boundaries = Set([now] + upcoming)
    var midnight = schedule.calendar.startOfDay(for: now)
    while let next = schedule.calendar.date(byAdding: .day, value: 1, to: midnight), next < horizon {
      boundaries.insert(next)
      midnight = next
    }
    let entries = boundaries.sorted().map(schedule.entry(at:))
    completion(Timeline(entries: entries, policy: .atEnd))
  }
}

struct PrayerWidgetView: View {
  @Environment(\.widgetFamily) private var family
  let entry: PrayerEntry

  var body: some View {
    Group {
      switch family {
      case .accessoryInline: inline
      case .accessoryRectangular: rectangular
      case .systemMedium: medium
      default: small
      }
    }
    .environment(\.layoutDirection, .rightToLeft)
    .widgetBackground(isAccessory ? nil : .fadlGreen)
  }

  private var isAccessory: Bool {
    family == .accessoryInline || family == .accessoryRectangular
  }

  @ViewBuilder private var inline: some View {
    if let next = entry.next {
      Text("\(next.name) \(next.local)")
    } else {
      Text("فضل: حدد موقعك")
    }
  }

  @ViewBuilder private var rectangular: some View {
    if let next = entry.next {
      VStack(alignment: .leading, spacing: 2) {
        Text("\(next.name) \(next.local)").font(.headline).widgetAccentable()
        Text(next.at, style: .timer).font(.body.monospacedDigit())
        if !entry.hijri.isEmpty {
          Text(entry.hijri).font(.caption2).lineLimit(1)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    } else {
      Text("حدد موقعك في فضل").font(.headline)
    }
  }

  private var small: some View {
    VStack(alignment: .leading, spacing: 3) {
      nextPrayer
      Spacer(minLength: 0)
      Text(entry.hijri)
        .font(.caption2)
        .foregroundColor(.white.opacity(0.75))
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }

  private var medium: some View {
    HStack(alignment: .top, spacing: 12) {
      small
      if !entry.today.isEmpty {
        Rectangle().fill(Color.fadlGold.opacity(0.4)).frame(width: 1)
        VStack(alignment: .leading, spacing: 3) {
          ForEach(entry.today, id: \.at) { prayer in
            let isNext = prayer.at == entry.next?.at
            HStack {
              Text(prayer.name)
              Spacer(minLength: 4)
              Text(prayer.local).monospacedDigit()
            }
            .font(.caption.weight(isNext ? .bold : .regular))
            .foregroundColor(isNext ? .fadlGold : .white.opacity(prayer.at < entry.date ? 0.55 : 0.9))
          }
        }
        .frame(maxWidth: .infinity)
      }
    }
  }

  @ViewBuilder private var nextPrayer: some View {
    if let next = entry.next {
      Text("الصلاة القادمة").font(.caption2).foregroundColor(.fadlGold)
      Text(next.name)
        .font(.title2.bold())
        .foregroundColor(.white)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
      Text(next.local).font(.headline).foregroundColor(.white.opacity(0.9))
      Text(next.at, style: .timer)
        .font(.subheadline.monospacedDigit())
        .foregroundColor(.fadlGold)
    } else {
      Text("فضل").font(.title2.bold()).foregroundColor(.fadlGold)
      Text("حدد موقعك في التطبيق لتظهر المواقيت")
        .font(.caption)
        .foregroundColor(.white)
    }
  }
}

private extension View {
  /// iOS 17 draws the background (and margins) itself; earlier versions
  /// need both added by hand. Lock-screen widgets keep the system look.
  @ViewBuilder func widgetBackground(_ color: Color?) -> some View {
    if #available(iOSApplicationExtension 17.0, *) {
      containerBackground(color ?? .clear, for: .widget)
    } else if let color {
      padding().background(color)
    } else {
      self
    }
  }
}

@main
struct PrayerWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "FadlPrayerWidget", provider: PrayerProvider()) { entry in
      PrayerWidgetView(entry: entry)
    }
    .configurationDisplayName("مواقيت الصلاة")
    .description("الصلاة القادمة والوقت المتبقي والتاريخ الهجري، بلا إنترنت.")
    .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
  }
}
