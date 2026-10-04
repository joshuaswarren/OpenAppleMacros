import Foundation
import WidgetKit
import SwiftUI

struct SimpleEntry: TimelineEntry {
    var date: Date
}

struct SimpleProvider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date())
    }
    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        completion(SimpleEntry(date: Date()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        completion(Timeline(entries: [SimpleEntry(date: Date())], policy: .never))
    }
}

struct MyWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "my", provider: SimpleProvider()) { entry in
            Text(entry.date, style: .time)
        }
    }
}

#Preview(as: .systemLarge, widget: { MyWidget() }, timelineProvider: { SimpleProvider() })
