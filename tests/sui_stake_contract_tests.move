#[test_only]
module sui_stake_contract::sui_staker_tests {
    use sui::test_scenario::{Self, Scenario};
    use sui::coin::{Self, mint_for_testing};
    use sui::sui::SUI;
    use sui::clock::{Self, Clock};
    use sui_stake_contract::sui_staker::{Self, AdminCap, StakingPool, StakeInfo};
    use std::debug;
    
    const ADMIN: address = @0xAD;
    const USER: address = @0xB0B;
    const USER2: address = @0xCAFE;
    const STAKE_AMOUNT: u64 = 1_000_000_000; // 1 SUI
    const LARGER_STAKE: u64 = 2_000_000_000; // 2 SUI
    
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
        debug::print(&clock);
        clock::share_for_testing(clock);

        // Verify objects exist before staking
        test_scenario::next_tx(&mut scenario, USER);
        {
            // Verify shared objects exist
            assert!(test_scenario::has_most_recent_shared<Clock>(), 1);
            assert!(test_scenario::has_most_recent_shared<StakingPool>(), 2);

            let mut pool = test_scenario::take_shared<StakingPool>(&scenario);
            let clock = test_scenario::take_shared<Clock>(&scenario);
            let coin = mint_for_testing(STAKE_AMOUNT, test_scenario::ctx(&mut scenario));
            
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

    #[test]
    fun test_multiple_stakers() {
        let mut scenario = test_scenario::begin(ADMIN);
        
        // Initialize contract
        test_scenario::next_tx(&mut scenario, ADMIN);
        {
            sui_staker::init_for_testing(test_scenario::ctx(&mut scenario));
        };

        // Create and share clock
        test_scenario::next_tx(&mut scenario, ADMIN);
        let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        debug::print(&clock);
        clock::share_for_testing(clock);

        // First user stakes
        test_scenario::next_tx(&mut scenario, USER);
        {
            assert!(test_scenario::has_most_recent_shared<Clock>(), 1);
            assert!(test_scenario::has_most_recent_shared<StakingPool>(), 2);
            let mut pool = test_scenario::take_shared<StakingPool>(&scenario);
            let clock = test_scenario::take_shared<Clock>(&scenario);
            let coin = mint_for_testing(STAKE_AMOUNT, test_scenario::ctx(&mut scenario));
            
            sui_staker::stake(
                &mut pool,
                coin,
                &clock,
                test_scenario::ctx(&mut scenario)
            );
            
            test_scenario::return_shared(clock);
            test_scenario::return_shared(pool);
        };

        // Second user stakes
        test_scenario::next_tx(&mut scenario, USER2);
        {
            assert!(test_scenario::has_most_recent_shared<Clock>(), 1);
            assert!(test_scenario::has_most_recent_shared<StakingPool>(), 2);
            let mut pool = test_scenario::take_shared<StakingPool>(&scenario);
            let clock = test_scenario::take_shared<Clock>(&scenario);
            let coin = mint_for_testing(LARGER_STAKE, test_scenario::ctx(&mut scenario));
            
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

    #[test]
    fun test_stake_unstake() {
        let mut scenario = test_scenario::begin(ADMIN);
        
        // Initialize contract
        test_scenario::next_tx(&mut scenario, ADMIN);
        {
            sui_staker::init_for_testing(test_scenario::ctx(&mut scenario));
        };

        // Add rewards as admin
        test_scenario::next_tx(&mut scenario, ADMIN);
        {
            let mut pool = test_scenario::take_shared<StakingPool>(&mut scenario);
            let admin_cap = test_scenario::take_from_sender<AdminCap>(&mut scenario);
            let mut clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
            let reward_coin = mint_for_testing(1000000000, test_scenario::ctx(&mut scenario));

            sui_staker::add_rewards(&admin_cap, &mut pool, reward_coin, &clock, test_scenario::ctx(&mut scenario));
            
            clock::share_for_testing(clock);
            test_scenario::return_to_sender(&mut scenario, admin_cap);
            test_scenario::return_shared(pool);
        };
        
        // User stakes
        test_scenario::next_tx(&mut scenario, USER);
        {
            let mut pool = test_scenario::take_shared<StakingPool>(&mut scenario);
            let clock = test_scenario::take_shared<Clock>(&mut scenario);
            let coin = mint_for_testing(STAKE_AMOUNT, test_scenario::ctx(&mut scenario));
            
            sui_staker::stake(&mut pool, coin, &clock, test_scenario::ctx(&mut scenario));
            
            test_scenario::return_shared(clock);
            test_scenario::return_shared(pool);
        };

        // Advance clock by 30 days
        test_scenario::next_tx(&mut scenario, ADMIN);
        {
            let mut clock = test_scenario::take_shared<Clock>(&mut scenario);
            clock::set_for_testing(&mut clock, 2592000000);
            test_scenario::return_shared(clock);
        };

        // User unstakes
        test_scenario::next_tx(&mut scenario, USER);
        {
            let mut pool = test_scenario::take_shared<StakingPool>(&mut scenario);
            let clock = test_scenario::take_shared<Clock>(&mut scenario);
            let stake_info = test_scenario::take_from_sender<StakeInfo>(&mut scenario);
            
            sui_staker::unstake(&mut pool, stake_info, &clock, test_scenario::ctx(&mut scenario));
            
            test_scenario::return_shared(clock);
            test_scenario::return_shared(pool);
        };
        
        test_scenario::end(scenario);
    }
}
