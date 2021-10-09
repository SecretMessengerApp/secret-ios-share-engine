//
//


import Foundation

enum AuthenticationState {
    case authenticated, unauthenticated
}

protocol AuthenticationStatusProvider {

    var state: AuthenticationState { get }

}
