module my_address::VestingToken {
    use aptos_framework::signer;
    use aptos_framework::coin;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::timestamp;

    
    struct VestingSchedule has store, key {
        total_amount: u64,      
        released_amount: u64,   
        start_time: u64,        
        cliff_duration: u64,    
        vesting_duration: u64,  
        beneficiary: address,   
    }

   
    const E_NOT_AUTHORIZED: u64 = 1;
    const E_INSUFFICIENT_BALANCE: u64 = 2;
    const E_CLIFF_NOT_REACHED: u64 = 3;
    const E_NO_TOKENS_TO_RELEASE: u64 = 4;

    
    public fun create_vesting_schedule(
        owner: &signer,
        beneficiary: address,
        total_amount: u64,
        cliff_duration: u64,    
        vesting_duration: u64  
    ) {
        let current_time = timestamp::now_seconds();
        
        
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

   
    public fun release_tokens(account: &signer, vesting_owner: address) acquires VestingSchedule {
        let vesting = borrow_global_mut<VestingSchedule>(vesting_owner);
        let current_time = timestamp::now_seconds();
        
        
        assert!(current_time >= vesting.start_time + vesting.cliff_duration, E_CLIFF_NOT_REACHED);
        
    
        let vested_amount = if (current_time >= vesting.start_time + vesting.vesting_duration) {
            vesting.total_amount
        } else {
            let time_elapsed = current_time - (vesting.start_time + vesting.cliff_duration);
            let vesting_period = vesting.vesting_duration - vesting.cliff_duration;
            (vesting.total_amount * time_elapsed) / vesting_period
        };
        
        let releasable_amount = vested_amount - vesting.released_amount;
        assert!(releasable_amount > 0, E_NO_TOKENS_TO_RELEASE);
        
        
        let release_tokens = coin::withdraw<AptosCoin>(account, releasable_amount);
        coin::deposit<AptosCoin>(vesting.beneficiary, release_tokens);
        
        vesting.released_amount = vesting.released_amount + releasable_amount;
    }

}
