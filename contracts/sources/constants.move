/// Module to wrap all constants used across the project. Not sure if we want
/// to keep it but better have it organized during the active development phase.
module suins::constants {
    use std::string::{utf8, String};

    /// The u64_MAX value.
    const MAX_U64: u64 = 18446744073709551615;

    /// The amount of MIST in 1 SUI.
    const MIST_PER_SUI: u64 = 1_000_000_000;

    /// The minimum length of a domain name.
    const MIN_DOMAIN_LENGTH: u8 = 3;

    /// The maximum length of a domain name.
    const MAX_DOMAIN_LENGTH: u8 = 63;

    /// Top level domain for SUI.
    const SUI_TLD: vector<u8> = b"sui";


    /// Top level domain for SUI as a String.
    public fun sui_tld(): String { utf8(SUI_TLD) }

    /// The amount of MIST in 1 SUI.
    public fun mist_per_sui(): u64 { MIST_PER_SUI }

    /// The minimum length of a domain name.
    public fun min_domain_length(): u8 { MIN_DOMAIN_LENGTH }

    /// The maximum length of a domain name.
    public fun max_domain_length(): u8 { MAX_DOMAIN_LENGTH }

    /// Maximum value for epoch.
    public fun max_epoch_allowed(): u64 { MAX_U64 - 365 }

    /// Maximum value of u64.
    public fun max_u64(): u64 { MAX_U64 }
}
