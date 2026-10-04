import Foundation

struct Book {
    var title: String
}

let localized = #Predicate<Book> { book in
    book.title.localizedStandardContains("swift")
}
let compared = #Predicate<Book> { book in
    book.title.localizedCompare("Swift") == .orderedSame
}
