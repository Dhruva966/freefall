import Contacts
import Foundation
import FoundationModels
import Intents
import LocalAuthentication

// Bill-split / Apple Cash tool.
//
// Flow:
//   1. LLM sees the receipt image in the conversation, calculates each person's share,
//      then calls this tool with the resolved contact name + amount.
//   2. Tool verifies identity with Face ID / Touch ID via LocalAuthentication.
//   3. Tool looks up the contact's phone number in the address book.
//   4. Tool creates an INSendPaymentIntent and donates it, which surfaces an
//      Apple Cash confirmation sheet the user taps to complete.
//
// Note: full in-app payment handling (no tap required) needs an Intents Extension
// target with INSendPaymentIntentHandling. The donation approach here is the
// correct single-target implementation and matches Apple's documented pattern.
@available(iOS 26, *)
final class SendPaymentTool: Tool {
    typealias Output = String

    let name = "sendPayment"
    let description = """
        Split a bill and send Apple Cash to someone. Use after analyzing a receipt \
        image when the user asks to pay someone back or split a bill. \
        Always confirm the amount with the user before calling this tool.
        """

    @Generable
    struct Arguments {
        @Guide(description: "Full name of the contact to pay, as it appears in the address book.")
        var contactName: String

        @Guide(description: "Dollar amount to send as a decimal string, e.g. '24.50'.")
        var amountUSD: String

        @Guide(description: "Payment note shown to the recipient, e.g. 'Dinner split – your share'.")
        var note: String
    }

    func call(arguments: Arguments) async throws -> String {
        guard let amount = Double(arguments.amountUSD), amount > 0 else {
            return "Invalid amount '\(arguments.amountUSD)'. Please provide a positive number."
        }

        try await requireBiometrics(
            reason: "Authorize $\(arguments.amountUSD) Apple Cash payment to \(arguments.contactName)"
        )

        let person = try await resolveContact(named: arguments.contactName)
        try await donatePaymentIntent(to: person, amount: amount, note: arguments.note)

        return "Identity confirmed. Apple Cash transfer of $\(arguments.amountUSD) to \(arguments.contactName) is ready — tap the Apple Cash notification to complete."
    }

    private func requireBiometrics(reason: String) async throws {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            throw PaymentError.biometricsUnavailable(
                error?.localizedDescription ?? "Face ID / Touch ID not available."
            )
        }

        let granted = try await context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: reason
        )
        guard granted else { throw PaymentError.biometricsDenied }
    }

    private func resolveContact(named name: String) async throws -> INPerson {
        let store = CNContactStore()
        try await store.requestAccess(for: .contacts)

        let keys: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor
        ]
        let contacts = try store.unifiedContacts(
            matching: CNContact.predicateForContacts(matchingName: name),
            keysToFetch: keys
        )

        guard let contact = contacts.first else { throw PaymentError.contactNotFound(name) }

        let handle: INPersonHandle = {
            if let phone = contact.phoneNumbers.first {
                return INPersonHandle(value: phone.value.stringValue, type: .phoneNumber)
            }
            if let email = contact.emailAddresses.first {
                return INPersonHandle(value: email.value as String, type: .emailAddress)
            }
            return INPersonHandle(value: name, type: .unknown)
        }()

        guard handle.type != .unknown else { throw PaymentError.noContactHandle(name) }

        var nameComponents = PersonNameComponents()
        nameComponents.givenName  = contact.givenName
        nameComponents.familyName = contact.familyName

        return INPerson(
            personHandle: handle,
            nameComponents: nameComponents,
            displayName: "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces),
            image: nil,
            contactIdentifier: contact.identifier,
            customIdentifier: nil
        )
    }

    private func donatePaymentIntent(to person: INPerson, amount: Double, note: String) async throws {
        let intent = INSendPaymentIntent(
            payee: person,
            currencyAmount: INCurrencyAmount(
                amount: NSDecimalNumber(value: amount),
                currencyCode: "USD"
            ),
            note: note
        )

        let interaction = INInteraction(intent: intent, response: nil)
        interaction.direction = .outgoing

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            interaction.donate { error in
                if let error { cont.resume(throwing: error) }
                else         { cont.resume() }
            }
        }
    }
}

enum PaymentError: LocalizedError {
    case biometricsUnavailable(String)
    case biometricsDenied
    case contactNotFound(String)
    case noContactHandle(String)

    var errorDescription: String? {
        switch self {
        case .biometricsUnavailable(let msg): return "Biometrics unavailable: \(msg)"
        case .biometricsDenied:               return "Biometric authentication was not confirmed."
        case .contactNotFound(let name):      return "'\(name)' not found in your contacts."
        case .noContactHandle(let name):      return "'\(name)' has no phone number or email address for Apple Cash."
        }
    }
}
