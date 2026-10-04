import Foundation

struct Account {
    var email: String?
    var nickname: String??
}

let hasEmail = #Predicate<Account> { account in
    account.email != nil
}
let emailIs = #Predicate<Account> { account in
    account.email == "a@b.c"
}
