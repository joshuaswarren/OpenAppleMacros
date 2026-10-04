import Foundation

struct Group {
    var members: [String]
    var tags: Set<String>
}

let hasAdmin = #Predicate<Group> { group in
    group.members.contains("admin")
}
let hasTag = #Predicate<Group> { group in
    group.tags.contains("vip")
}
let hasPrefix = #Predicate<Group> { group in
    group.members.first!.hasPrefix("a")
}
