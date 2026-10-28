import SwiftUI

/// Owns the rider's per-user stores so every tab shares the same instances.
/// Each store is keyed by `rider.id`, so one rider's saved places, scheduled rides, favourites,
/// loyalty points and referrals are kept apart from another account's on the same device.
@MainActor
@Observable
final class RiderRootViewModel {
    let rider: AppUser
    /// Home/work and other saved addresses.
    let savedPlacesStore: SavedPlacesStore
    /// Rides booked for later.
    let scheduledRidesStore: ScheduledRidesStore
    /// Drivers the rider marked as favourites.
    let favoriteDriversStore: FavoriteDriversStore
    /// Points earned from completed trips.
    let loyaltyStore: LoyaltyStore
    /// The rider's referral code and invites.
    let referralStore: ReferralStore

    init(rider: AppUser) {
        self.rider = rider
        savedPlacesStore = SavedPlacesStore(userId: rider.id)
        scheduledRidesStore = ScheduledRidesStore(userId: rider.id)
        favoriteDriversStore = FavoriteDriversStore(userId: rider.id)
        loyaltyStore = LoyaltyStore(userId: rider.id)
        referralStore = ReferralStore(userId: rider.id)
    }
}
