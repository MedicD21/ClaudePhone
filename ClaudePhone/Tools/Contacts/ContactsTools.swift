import Foundation
import Contacts

private let contactStore = CNContactStore()

private func requestContactsAccess() async throws {
    let status = CNContactStore.authorizationStatus(for: .contacts)
    if status == .notDetermined {
        let granted = try await contactStore.requestAccess(for: .contacts)
        if !granted {
            throw ToolError.permissionDenied("Contacts access was denied")
        }
    } else if status == .denied || status == .restricted {
        throw ToolError.permissionDenied("Contacts access is restricted. Please enable in Settings.")
    }
}

// MARK: - Search Contacts
struct SearchContactsTool: ClaudeTool {
    let name = "search_contacts"
    let description = "Search contacts by name, phone number, or email address"
    let category = ToolCategory.contacts

    let parameters = [
        ToolParameter(name: "query", type: .string, description: "Search query (name, phone, or email)", isRequired: true),
        ToolParameter(name: "limit", type: .integer, description: "Maximum results to return (default 10)")
    ]

    let requiredParams = ["query"]

    func execute(with arguments: [String: Any]) async throws -> String {
        try await requestContactsAccess()

        guard let query = arguments["query"] as? String else {
            throw ToolError.invalidArguments("query is required")
        }

        let limit = arguments["limit"] as? Int ?? 10

        let keysToFetch: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactOrganizationNameKey as CNKeyDescriptor,
            CNContactIdentifierKey as CNKeyDescriptor
        ]

        let predicate = CNContact.predicateForContacts(matchingName: query)
        let contacts = try contactStore.unifiedContacts(matching: predicate, keysToFetch: keysToFetch)
            .prefix(limit)

        if contacts.isEmpty {
            return "No contacts found matching '\(query)'."
        }

        var result = "Found \(contacts.count) contact(s):\n\n"
        for (i, contact) in contacts.enumerated() {
            let name = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
            result += "\(i + 1). \(name.isEmpty ? "No Name" : name)\n"

            if !contact.organizationName.isEmpty {
                result += "   Organization: \(contact.organizationName)\n"
            }

            for phone in contact.phoneNumbers {
                let label = CNLabeledValue<CNPhoneNumber>.localizedString(forLabel: phone.label ?? "")
                result += "   Phone (\(label)): \(phone.value.stringValue)\n"
            }

            for email in contact.emailAddresses {
                let label = CNLabeledValue<NSString>.localizedString(forLabel: email.label ?? "")
                result += "   Email (\(label)): \(email.value as String)\n"
            }

            result += "   ID: \(contact.identifier)\n\n"
        }

        return result
    }
}

// MARK: - Create Contact
struct CreateContactTool: ClaudeTool {
    let name = "create_contact"
    let description = "Create a new contact with name, phone, email, and organization"
    let category = ToolCategory.contacts

    let parameters = [
        ToolParameter(name: "first_name", type: .string, description: "First name", isRequired: true),
        ToolParameter(name: "last_name", type: .string, description: "Last name"),
        ToolParameter(name: "phone", type: .string, description: "Phone number"),
        ToolParameter(name: "email", type: .string, description: "Email address"),
        ToolParameter(name: "organization", type: .string, description: "Organization/Company name")
    ]

    let requiredParams = ["first_name"]

    func execute(with arguments: [String: Any]) async throws -> String {
        try await requestContactsAccess()

        guard let firstName = arguments["first_name"] as? String else {
            throw ToolError.invalidArguments("first_name is required")
        }

        let contact = CNMutableContact()
        contact.givenName = firstName

        if let lastName = arguments["last_name"] as? String {
            contact.familyName = lastName
        }

        if let phone = arguments["phone"] as? String {
            contact.phoneNumbers = [CNLabeledValue(label: CNLabelPhoneNumberMobile, value: CNPhoneNumber(stringValue: phone))]
        }

        if let email = arguments["email"] as? String {
            contact.emailAddresses = [CNLabeledValue(label: CNLabelWork, value: email as NSString)]
        }

        if let org = arguments["organization"] as? String {
            contact.organizationName = org
        }

        let saveRequest = CNSaveRequest()
        saveRequest.add(contact, toContainerWithIdentifier: nil)
        try contactStore.execute(saveRequest)

        let fullName = "\(firstName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
        var result = "Contact created successfully:\n- Name: \(fullName)"
        if let phone = arguments["phone"] as? String { result += "\n- Phone: \(phone)" }
        if let email = arguments["email"] as? String { result += "\n- Email: \(email)" }
        if let org = arguments["organization"] as? String { result += "\n- Organization: \(org)" }

        return result
    }
}

// MARK: - Get Contact Details
struct GetContactDetailsTool: ClaudeTool {
    let name = "get_contact_details"
    let description = "Get full details of a contact by their identifier"
    let category = ToolCategory.contacts

    let parameters = [
        ToolParameter(name: "contact_id", type: .string, description: "Contact identifier from a previous search", isRequired: true)
    ]

    let requiredParams = ["contact_id"]

    func execute(with arguments: [String: Any]) async throws -> String {
        try await requestContactsAccess()

        guard let contactId = arguments["contact_id"] as? String else {
            throw ToolError.invalidArguments("contact_id is required")
        }

        let keysToFetch: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactPostalAddressesKey as CNKeyDescriptor,
            CNContactBirthdayKey as CNKeyDescriptor,
            CNContactOrganizationNameKey as CNKeyDescriptor,
            CNContactJobTitleKey as CNKeyDescriptor,
            CNContactNoteKey as CNKeyDescriptor,
            CNContactUrlAddressesKey as CNKeyDescriptor
        ]

        let predicate = CNContact.predicateForContacts(withIdentifiers: [contactId])
        let contacts = try contactStore.unifiedContacts(matching: predicate, keysToFetch: keysToFetch)

        guard let contact = contacts.first else {
            throw ToolError.executionFailed("Contact not found")
        }

        let name = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
        var result = "Contact Details:\n"
        result += "- Name: \(name.isEmpty ? "No Name" : name)\n"

        if !contact.organizationName.isEmpty { result += "- Organization: \(contact.organizationName)\n" }
        if !contact.jobTitle.isEmpty { result += "- Job Title: \(contact.jobTitle)\n" }

        for phone in contact.phoneNumbers {
            let label = CNLabeledValue<CNPhoneNumber>.localizedString(forLabel: phone.label ?? "")
            result += "- Phone (\(label)): \(phone.value.stringValue)\n"
        }

        for email in contact.emailAddresses {
            let label = CNLabeledValue<NSString>.localizedString(forLabel: email.label ?? "")
            result += "- Email (\(label)): \(email.value as String)\n"
        }

        for address in contact.postalAddresses {
            let label = CNLabeledValue<CNPostalAddress>.localizedString(forLabel: address.label ?? "")
            let formatted = CNPostalAddressFormatter.string(from: address.value, style: .mailingAddress)
            result += "- Address (\(label)): \(formatted.replacingOccurrences(of: "\n", with: ", "))\n"
        }

        if let birthday = contact.birthday, let date = Calendar.current.date(from: birthday) {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            result += "- Birthday: \(formatter.string(from: date))\n"
        }

        for url in contact.urlAddresses {
            result += "- URL: \(url.value as String)\n"
        }

        if !contact.note.isEmpty { result += "- Notes: \(contact.note)\n" }

        return result
    }
}
