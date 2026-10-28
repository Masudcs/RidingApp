import Foundation

/// Multi-rail payment methods for Phase 1. `MFS` (mobile financial services) covers the three
/// Bangladeshi rails explicitly named in the brief; more can be added without touching call sites
/// that switch on `.category`.
public enum PaymentMethodType: String, CaseIterable, Codable, Sendable, Identifiable {
    case cash
    case wallet
    case bKash
    case nagad
    case rocket
    case card

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .cash: return String(localized: "Cash")
        case .wallet: return String(localized: "In-App Wallet")
        case .bKash: return "bKash"
        case .nagad: return "Nagad"
        case .rocket: return "Rocket"
        case .card: return String(localized: "Credit / Debit Card")
        }
    }

    public var systemImageName: String {
        switch self {
        case .cash: return "banknote"
        case .wallet: return "wallet.pass.fill"
        case .bKash, .nagad, .rocket: return "iphone.gen3"
        case .card: return "creditcard.fill"
        }
    }

    /// Groups payment methods for UI and rules, so callers do not switch over every method.
    public enum Category {
        case cash
        case wallet
        case mobileFinancialService
        case card
    }

    public var category: Category {
        switch self {
        case .cash: return .cash
        case .wallet: return .wallet
        case .bKash, .nagad, .rocket: return .mobileFinancialService
        case .card: return .card
        }
    }
}

/// A payment method the user has linked. Only a masked identifier is stored, never full numbers.
public struct PaymentMethodAccount: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    public let type: PaymentMethodType
    /// Masked identifier, e.g. "•••• 4242" or "•••• 8821" for an MFS-linked number.
    public let maskedIdentifier: String
    public let isDefault: Bool

    public init(id: String = UUID().uuidString, type: PaymentMethodType, maskedIdentifier: String, isDefault: Bool = false) {
        self.id = id
        self.type = type
        self.maskedIdentifier = maskedIdentifier
        self.isDefault = isDefault
    }
}

/// Payment lifecycle: pending -> authorized -> captured, or failed / refunded.
public enum PaymentStatus: String, Codable, Sendable {
    case pending
    case authorized
    case captured
    case failed
    case refunded
}

/// Record of what a rider paid for a trip, with the pieces that make up `amount` broken out.
public struct PaymentReceipt: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    public let tripId: String
    public let method: PaymentMethodType
    public let amount: Money
    public let status: PaymentStatus
    public let createdAt: Date
    /// Bundled micro-insurance premium, already included in `amount`; broken out here for receipt display.
    public let insurancePremium: Money
    public let promoCode: String?
    /// Already subtracted from `amount`; broken out here so the receipt can show "You saved ৳X".
    public let discountApplied: Money
    /// Already included in `amount`; broken out here for receipt display.
    public let tipAmount: Money
    /// How many people the fare (+ tip) was split across; `amount` is this rider's own share.
    public let splitCount: Int

    public init(
        id: String = UUID().uuidString,
        tripId: String,
        method: PaymentMethodType,
        amount: Money,
        status: PaymentStatus,
        createdAt: Date = Date(),
        insurancePremium: Money = Money(minorUnits: 0),
        promoCode: String? = nil,
        discountApplied: Money = Money(minorUnits: 0),
        tipAmount: Money = Money(minorUnits: 0),
        splitCount: Int = 1
    ) {
        self.id = id
        self.tripId = tripId
        self.method = method
        self.amount = amount
        self.status = status
        self.createdAt = createdAt
        self.insurancePremium = insurancePremium
        self.promoCode = promoCode
        self.discountApplied = discountApplied
        self.tipAmount = tipAmount
        self.splitCount = splitCount
    }
}

#if DEBUG

// Fixed fake data for SwiftUI previews. Debug builds only, so none of it ships.
// Defaults let a preview override just the field it is about.

public extension PaymentMethodAccount {
    static func mockList() -> [PaymentMethodAccount] {
        [
            PaymentMethodAccount(id: "pm-1", type: .cash, maskedIdentifier: "Cash", isDefault: true),
            PaymentMethodAccount(id: "pm-2", type: .bKash, maskedIdentifier: "01XXXXXXX00")
        ]
    }
}

public extension PaymentReceipt {
    static func mock(method: PaymentMethodType = .cash, status: PaymentStatus = .captured) -> PaymentReceipt {
        PaymentReceipt(
            id: "receipt-1",
            tripId: "trip-1",
            method: method,
            amount: .bdt(223),
            status: status,
            insurancePremium: defaultInsurancePremium
        )
    }
}

#endif
