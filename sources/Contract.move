module my_address::VestingToken {
    use aptos_framework::signer;
    use aptos_framework::coin;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::timestamp;

    /// Struct representing a vesting schedule
    struct VestingSchedule has store, key {
        total_amount: u64,      // Total tokens to be vested
        released_amount: u64,   // Amount already released
        start_time: u64,        // Vesting start timestamp
        cliff_duration: u64,    // Cliff period in seconds
        vesting_duration: u64,  // Total vesting duration in seconds
        beneficiary: address,   // Address of the beneficiary
    }

    /// Error codes
    const E_NOT_AUTHORIZED: u64 = 1;
    const E_INSUFFICIENT_BALANCE: u64 = 2;
    const E_CLIFF_NOT_REACHED: u64 = 3;
    const E_NO_TOKENS_TO_RELEASE: u64 = 4;

    /// Function to create a new vesting schedule
    public fun create_vesting_schedule(
        owner: &signer,
        beneficiary: address,
        total_amount: u64,
        cliff_duration: u64,    // in seconds
        vesting_duration: u64   // in seconds
    ) {
        let current_time = timestamp::now_seconds();
        
        // Transfer tokens from owner to contract
        let vesting_tokens = coin::withdraw<AptosCoin>(owner, total_amount);
        coin::deposit<AptosCoin>(signer::address_of(owner), vesting_tokens);
        
        let vesting_schedule = VestingSchedule {
            total_amount,
            released_amount: 0,
            start_time: current_time,
            cliff_duration,
            vesting_duration,
            beneficiary,
        };
        
        move_to(owner, vesting_schedule);
    }

    /// Function to release vested tokens to beneficiary
    public fun release_tokens(account: &signer, vesting_owner: address) acquires VestingSchedule {
        let vesting = borrow_global_mut<VestingSchedule>(vesting_owner);
        let current_time = timestamp::now_seconds();
        
        // Check if cliff period has passed
        assert!(current_time >= vesting.start_time + vesting.cliff_duration, E_CLIFF_NOT_REACHED);
        
        // Calculate vested amount based on linear schedule
        let vested_amount = if (current_time >= vesting.start_time + vesting.vesting_duration) {
            vesting.total_amount
        } else {
            let time_elapsed = current_time - (vesting.start_time + vesting.cliff_duration);
            let vesting_period = vesting.vesting_duration - vesting.cliff_duration;
            (vesting.total_amount * time_elapsed) / vesting_period
        };
        
        let releasable_amount = vested_amount - vesting.released_amount;
        assert!(releasable_amount > 0, E_NO_TOKENS_TO_RELEASE);
        
        // Transfer tokens to beneficiary
        let release_tokens = coin::withdraw<AptosCoin>(account, releasable_amount);
        coin::deposit<AptosCoin>(vesting.beneficiary, release_tokens);
        
        // Update released amount
        vesting.released_amount = vesting.released_amount + releasable_amount;
    }
}