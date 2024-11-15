module sui_stake_contract::sui_staker {
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::sui::SUI;
    use sui::balance::{Self, Balance};
    use sui::tx_context::{Self, TxContext};
    use sui::coin::{Self, Coin};
    use sui::clock::{Self, Clock};
    use sui::event;
    
    // Error codes
    const E_INSUFFICIENT_BALANCE: u64 = 1;
    const E_NO_STAKE_FOUND: u64 = 2;
    const E_MINIMUM_STAKING_PERIOD_NOT_MET: u64 = 3;
    const E_INVALID_OWNER: u64 = 4;
    const E_INSUFFICIENT_REWARDS: u64 = 5;
    const E_ZERO_STAKE: u64 = 6;
    
    // Constants - using more precise values
    const MINIMUM_STAKE_AMOUNT: u64 = 1_000_000_000; // 1 SUI (considering decimals)
    const MINIMUM_STAKING_PERIOD: u64 = 86400000; // 24 hours in milliseconds
    const REWARD_RATE: u64 = 500; // 5% APY (in basis points)
    const BASIS_POINTS: u64 = 10000;
    const MS_PER_YEAR: u64 = 31536000000; // Milliseconds in a year
    
    // Capability for admin functions
    public struct AdminCap has key { id: UID }
    
    // Staking Pool with added fields for better tracking
    public struct StakingPool has key {
        id: UID,
        total_staked: Balance<SUI>,
        total_rewards: Balance<SUI>,
        total_stakes: u64,
        last_update_time: u64
    }
    
    // Enhanced stake information
    public struct StakeInfo has key, store {
        id: UID,
        amount: u64,
        start_time: u64,
        accumulated_rewards: u64,
        owner: address
    }
    
    // Enhanced events
    public struct StakeEvent has copy, drop {
        staker: address,
        amount: u64,
        timestamp: u64
    }
    
    public struct UnstakeEvent has copy, drop {
        staker: address,
        amount: u64,
        reward: u64,
        timestamp: u64
    }
    
    public struct RewardsAddedEvent has copy, drop {
        amount: u64,
        timestamp: u64
    }
    
    fun init(ctx: &mut TxContext) {
        // Create and transfer admin capability
        transfer::transfer(AdminCap {
            id: object::new(ctx)
        }, tx_context::sender(ctx));
        
        // Initialize staking pool
        let staking_pool = StakingPool {
            id: object::new(ctx),
            total_staked: balance::zero(),
            total_rewards: balance::zero(),
            total_stakes: 0,
            last_update_time: 0
        };
        transfer::share_object(staking_pool);
    }
    
    public entry fun stake(
        pool: &mut StakingPool,
        payment: Coin<SUI>,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let amount = coin::value(&payment);
        
        // Validations
        assert!(amount > 0, E_ZERO_STAKE);
        assert!(amount >= MINIMUM_STAKE_AMOUNT, E_INSUFFICIENT_BALANCE);
        
        // Update pool
        let payment_balance = coin::into_balance(payment);
        balance::join(&mut pool.total_staked, payment_balance);
        pool.total_stakes = pool.total_stakes + 1;
        
        let current_time = clock::timestamp_ms(clock);
        if (pool.last_update_time == 0) {
            pool.last_update_time = current_time;
        };
        
        // Create stake info with accumulated rewards tracking
        let stake_info = StakeInfo {
            id: object::new(ctx),
            amount,
            start_time: current_time,
            accumulated_rewards: 0,
            owner: tx_context::sender(ctx)
        };
        
        transfer::transfer(stake_info, tx_context::sender(ctx));
        
        event::emit(StakeEvent {
            staker: tx_context::sender(ctx),
            amount,
            timestamp: current_time
        });
    }
    
    fun calculate_rewards(amount: u64, start_time: u64, current_time: u64): u64 {
        let time_staked = current_time - start_time;
        // More precise calculation using milliseconds
        let reward = (amount * REWARD_RATE * time_staked) / (BASIS_POINTS * MS_PER_YEAR);
        reward
    }
    
    public entry fun unstake(
        pool: &mut StakingPool,
        stake_info: StakeInfo,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let StakeInfo { id, amount, start_time, accumulated_rewards: _, owner } = stake_info;
        let sender = tx_context::sender(ctx);
        
        // Validations
        assert!(owner == sender, E_INVALID_OWNER);
        
        let current_time = clock::timestamp_ms(clock);
        let time_staked = current_time - start_time;
        assert!(time_staked >= MINIMUM_STAKING_PERIOD, E_MINIMUM_STAKING_PERIOD_NOT_MET);
        
        // Calculate and verify rewards
        let reward_amount = calculate_rewards(amount, start_time, current_time);
        assert!(balance::value(&pool.total_rewards) >= reward_amount, E_INSUFFICIENT_REWARDS);
        
        // Update pool state
        pool.total_stakes = pool.total_stakes - 1;
        pool.last_update_time = current_time;
        
        // Process unstaking
        object::delete(id);
        let staked_coin = coin::take(&mut pool.total_staked, amount, ctx);
        transfer::public_transfer(staked_coin, owner);
        
        // Process rewards
        if (reward_amount > 0) {
            let reward_coin = coin::take(&mut pool.total_rewards, reward_amount, ctx);
            transfer::public_transfer(reward_coin, owner);
        };
        
        event::emit(UnstakeEvent {
            staker: owner,
            amount,
            reward: reward_amount,
            timestamp: current_time
        });
    }
    
    // Admin function to add rewards - now requires AdminCap
    public entry fun add_rewards(
        _: &AdminCap,
        pool: &mut StakingPool,
        rewards: Coin<SUI>,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let reward_amount = coin::value(&rewards);
        let rewards_balance = coin::into_balance(rewards);
        balance::join(&mut pool.total_rewards, rewards_balance);
        
        event::emit(RewardsAddedEvent {
            amount: reward_amount,
            timestamp: clock::timestamp_ms(clock)
        });
    }
    
    // View functions
    public fun get_stake_info(stake_info: &StakeInfo): (u64, u64, u64, address) {
        (stake_info.amount, stake_info.start_time, stake_info.accumulated_rewards, stake_info.owner)
    }
    
    public fun get_pool_info(pool: &StakingPool): (u64, u64, u64) {
        (
            balance::value(&pool.total_staked),
            balance::value(&pool.total_rewards),
            pool.total_stakes
        )
    }
    
    public fun get_minimum_stake_amount(): u64 {
        MINIMUM_STAKE_AMOUNT
    }
    
    public fun get_minimum_staking_period(): u64 {
        MINIMUM_STAKING_PERIOD
    }
    
    public fun get_reward_rate(): u64 {
        REWARD_RATE
    }
    
    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx)
    }
}
