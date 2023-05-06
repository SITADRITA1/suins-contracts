/// Copying controller logic here to see what we can do with it.
/// Stores the main user interaction logic (except for the Auction).
module suins::controller {
    use std::vector;
    use std::string::{utf8, String};
    // use sui::coin::{Self, Coin};
    use sui::tx_context::TxContext;
    // use sui::clock::{timestamp_ms, Clock};
    use sui::clock::Clock;
    // use sui::sui::SUI;
    // use sui::object;
    use sui::bcs;
    use sui::ecdsa_k1;

    use suins::domain;
    // use suins::constants;
    // use suins::name_record;
    // use suins::registry::{Self, Registry};
    use suins::suins::{Self, SuiNS};
    use suins::config::{Self, Config};
    use suins::registration_nft::{Self as nft, RegistrationNFT};

    /// Number of years passed is not within [1-5] interval.
    const EInvalidYearsArgument: u64 = 0;
    /// Trying to register a subdomain (only *.sui is currently allowed).
    const EInvalidDomain: u64 = 1;
    /// Trying to register a domain name in a different TLD (not .sui).
    const EInvalidTld: u64 = 2;
    /// Trying to register domain name that is shorter than 6 symbols.
    const EInvalidDomainLength: u64 = 3;
    /// The payment does not match the price for the domain.
    const EIncorrectAmount: u64 = 4;
    /// Trying to purchase a domain that is already registered and active.
    const ENotExpired: u64 = 5;
    /// The NFT does not match the currently active `nft_id` in the `NameRecord`.
    const EInvalidToken: u64 = 6;

    /// Trying to update an image in an expired `RegistrationNFT`.
    const EExpired: u64 = 0;
    /// Message data cannot be parsed.
    const EInvalidData: u64 = 1;
    /// The parsed name does not match the expected domain.
    const EInvalidDomainData: u64 = 2;
    const ESignatureNotMatch: u64 = 210;


    /// Authorization token for the app.
    struct RegistrationApp has drop {}

    // Allows direct purchases on domains longer than 5 symbols (6+ symbols).
    //
    // Makes sure that:
    // - the domain is not already registered (or, if active, expired)
    // - the domain TLD is .sui
    // - the domain is not a subdomain
    // - the domain length is higher than 5 symbols
    // - number of years is within [1-5] interval
    // public fun register(
    //     suins: &mut SuiNS,
    //     domain_name: String,
    //     no_years: u8,
    //     payment: Coin<SUI>,
    //     clock: &Clock,
    //     ctx: &mut TxContext
    // ): RegistrationNFT {
    //     let config = suins::get_config<Config>(suins);
    //     let price = config::calculate_price(config, 6, no_years);
    //     let domain = domain::new(domain_name);
    //     let labels = domain::labels(&domain);

    //     assert!(vector::length(labels) == 2, EInvalidDomain);
    //     assert!(string::length(vector::borrow(labels, 0)) > 5, EInvalidDomainLength);
    //     assert!(domain::tld(&domain) == &constants::sui_tld(), EInvalidTld);
    //     assert!(0 < no_years && no_years <= 5, EInvalidYearsArgument);
    //     assert!(coin::value(&payment) == price, EIncorrectAmount);

    //     // if the domain is already registered but expired (!) we can re-register it
    //     if (suins::has_name_record(suins, domain)) {
    //         assert!(name_record::has_expired(suins::name_record(suins, domain), clock), ENotExpired);
    //     };

    //     suins::app_add_balance(App {}, suins, coin::into_balance(payment));
    //     suins::app_add_record(App {}, suins, domain, no_years, clock, ctx)
    // }

    // /// Renew a registered domain name by a number of years (not exceeding 5).
    // /// The domain name must be already registered and active; `RegistrationNFT`
    // /// serves as the proof of that.
    // ///
    // /// We make sure that (in order):
    // /// - the domain is already registered and active
    // /// - the RegistrationNFT matches the NameRecord.nft_id
    // /// - the domain TLD is .sui
    // /// - the domain is not a subdomain
    // /// - number of years is within [1-5] interval
    // /// - the new expiration does not exceed 5 years from now
    // /// - the payment matches the price for the domain
    // ///
    // /// TODO: update the record via SuiNS.
    // public fun renew(
    //     suins: &mut SuiNS,
    //     token: &mut RegistrationNFT,
    //     no_years: u8,
    //     payment: Coin<SUI>,
    //     clock: &Clock,
    // ) {
    //     let domain = nft::domain(token);

    //     let labels = domain::labels(&domain);
    //     let label_len = (string::length(vector::borrow(labels, 0)) as u8);
    //     let config = suins::get_config<Config>(suins);
    //     let price = config::calculate_price(config, label_len, no_years);
    //     let name_record = suins::name_record(suins, domain);
    //     // to be used to check if the new expiration is within 5 years from now
    //     let _max_expires = timestamp_ms(clock) + (5 * constants::year_ms());

    //     assert!(vector::length(labels) == 2, EInvalidDomain);
    //     assert!(domain::tld(&domain) == &constants::sui_tld(), EInvalidTld);
    //     assert!(0 < no_years && no_years <= 5, EInvalidYearsArgument);
    //     assert!(coin::value(&payment) == price, EIncorrectAmount);
    //     assert!(name_record::nft_id(name_record) == object::id(token), EInvalidToken);

    //     suins::app_add_balance(App {}, suins, coin::into_balance(payment));
    //     // update the record
    // }

    // === Update Image Functionality ===

    /// Authorization token for the update image feature
    struct UpdateImageApp has drop {}

    /// Updates the image attached to a `RegistrationNFT`.
    public fun update_image_url(
       suins: &mut SuiNS,
       nft: &mut RegistrationNFT,
       raw_msg: vector<u8>,
       signature: vector<u8>,
       clock: &Clock,
       _ctx: &mut TxContext,
    ) {
        suins::assert_app_is_authorized<UpdateImageApp>(suins);
        // let registry = suins::registry<Registry>(suins);
        let config = suins::get_config<Config>(suins);

        assert!(
            ecdsa_k1::secp256k1_verify(&signature, config::public_key(config), &raw_msg, 1),
            ESignatureNotMatch
        );

        let (ipfs_hash, domain_name, expiration_timestamp_ms, _data) = image_data_from_bcs(raw_msg);

        assert!(!nft::has_expired(nft, clock), EExpired);
        assert!(nft::expiration_timestamp_ms(nft) == expiration_timestamp_ms, EInvalidData);
        assert!(domain::to_string(&nft::domain(nft)) == domain_name, EInvalidDomainData);

        nft::update_image_url(nft, ipfs_hash);

        // TODO emit an event
        // event::emit(ImageUpdatedEvent {
        //     sender: tx_context::sender(ctx),
        //     domain_name: nft.name,
        //     new_image: nft.url,
        //     data: additional_data,
        // })
    }

    /// Parses the message bytes into the image data.
    /// ```
    /// struct MessageData {
    ///   ipfs_hash: String,
    ///   domain_name: String,
    ///   expiration_timestamp_ms: u64,
    ///   data: String
    /// }
    /// ```
    fun image_data_from_bcs(msg_bytes: vector<u8>): (String, String, u64, String) {
        let bcs = bcs::new(msg_bytes);

        let ipfs_hash = utf8(bcs::peel_vec_u8(&mut bcs));
        let domain_name = utf8(bcs::peel_vec_u8(&mut bcs));
        let expiration_timestamp_ms = bcs::peel_u64(&mut bcs);
        let data = utf8(bcs::peel_vec_u8(&mut bcs));

        let remainder = bcs::into_remainder_bytes(bcs);
        vector::destroy_empty(remainder);

        (
            ipfs_hash,
            domain_name,
            expiration_timestamp_ms,
            data,
        )
    }
}
