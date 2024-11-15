#[test_only]
module sui_stake_contract::sui_staker_tests {
    use sui::test_scenario::{Self, Scenario};
    use sui::coin::{Self, mint_for_testing};
    use sui::sui::SUI;
    use sui::clock::{Self, Clock};
    use sui_stake_contract::sui_staker::{Self, AdminCap, StakingPool};
    use sui::object;
    use std::debug;
    
    const ADMIN: address = @0xAD;
    const USER: address = @0xB0B;
    const STAKE_AMOUNT: u64 = 1_000_000_000; // 1 SUI

    #[test]
    fun test_init() {
        let mut scenario = test_scenario::begin(ADMIN);
        
        test_scenario::next_tx(&mut scenario, ADMIN);
        {
            sui_staker::init_for_testing(test_scenario::ctx(&mut scenario));
        };
        test_scenario::next_tx(&mut scenario, ADMIN);
        {
            assert!(test_scenario::has_most_recent_for_sender<AdminCap>(&scenario), 0);
        };
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_basic_stake() {
        let mut scenario = test_scenario::begin(ADMIN);
        
        // Initialize contract
        test_scenario::next_tx(&mut scenario, ADMIN);
        {
            sui_staker::init_for_testing(test_scenario::ctx(&mut scenario));
        };

        // Create and share clock
        test_scenario::next_tx(&mut scenario, ADMIN);
        let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        debug::print(&object::id(&clock));
        clock::share_for_testing(clock);

        // Verify objects exist before staking
        test_scenario::next_tx(&mut scenario, USER);
        {
            // Verify shared objects exist
            assert!(test_scenario::has_most_recent_shared<Clock>(), 1);
            assert!(test_scenario::has_most_recent_shared<StakingPool>(), 2);

            let mut pool = test_scenario::take_shared<StakingPool>(&scenario);
            let clock = test_scenario::take_shared<Clock>(&scenario);
            let coin = mint_for_testing<SUI>(STAKE_AMOUNT, test_scenario::ctx(&mut scenario));
            
            sui_staker::stake(
                &mut pool,
                coin,
                &clock,
                test_scenario::ctx(&mut scenario)
            );
            
            test_scenario::return_shared(clock);
            test_scenario::return_shared(pool);
        };
        
        test_scenario::end(scenario);
    }
}
