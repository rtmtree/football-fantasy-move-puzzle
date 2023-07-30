/*
    This puzzle involves creating a smart contract for a football fantasy game.
    The game is simple, each user can create a team of 3 players and the team
    will get points based on the performance of the players in the real world.
    The smart contract will be responsible for keeping data of the teams.
    The smart contract will also be responsible for announcing the result with players' stat data.
*/

module rtmtree::foot_fantasy {
    use std::signer;
    use std::vector;
    use aptos_framework::coin;
    use aptos_framework::aptos_coin::{Self, AptosCoin};
    use aptos_framework::account::{Self, SignerCapability};
    use aptos_framework::event::{Self, EventHandle};
    use aptos_framework::timestamp;
    use rtmtree::foot_fantasy_events::{
        CreateTeamEvent,
        AnnounceResultEvent,
        ClaimRewardEvent
    };

    /////////////////////////////
    // ERRORS //// DO NOT EDIT //
    /////////////////////////////

    const ERROR_SIGNER_NOT_ADMIN: u64 = 0;
    const ERROR_STATE_NOT_INITIALIZED: u64 = 1;
    const ERROR_LENGTHS_NOT_EQUAL: u64 = 2;
    const ERROR_PLAYER_DOES_NOT_EXIST: u64 = 3;
    const ERROR_DUPLICATE_PLAYER_ID: u64 = 4;
    const ERROR_RESULT_ALREADY_ANNOUNCED: u64 = 5;
    const ERROR_RESULT_IS_NOT_ANNOUNCED: u64 = 6;
    const ERROR_REWARD_IS_ALREADY_CLAIMED: u64 = 7;
    const ERROR_NOT_ENOUGH_BALANCE_TO_REWARD: u64 = 8;

    ///////////////////////////////
    // PDA Seed //// DO NOT EDIT //
    ///////////////////////////////

    const SEED: vector<u8> = b"RTMTREE_TO_OVERMIND";

    //////////////////////////////////////////////
    // POINT PER ACTION SETTINGS // DO NOT EDIT //
    //////////////////////////////////////////////

    const POINT_PER_GOAL: u64 = 6;
    const POINT_PER_ASSIST: u64 = 3;
    const REWARD_TOP10: u64 = 2000000;

    /////////////////////////////////
    // PLAYER NAMES // DO NOT EDIT //
    /////////////////////////////////

    const PLAYER_NAMES: vector<vector<u8>> = vector[
        b"Salah",
        b"Rashford",
        b"Bruno Fernandes",
        b"De Bruyne",
        b"Trent",
        b"Maquire",
    ];

    ////////////////////////////
    // STRUCTS // DO NOT EDIT //
    ////////////////////////////

    /*
        Resource kept under admin address. Stores data about players and teams.
    */
    struct State has key {
        // PDA's SingerCapability
        cap: SignerCapability,
        // Player List
        player_list: vector<Player>,
        // Team List
        team_list: vector<Team>,
        // is result announced
        is_result_announced: bool,
        // Events
        events: Event
    }

    /*
        Holds data about a football player
    */
    struct Player has key, store {
        id: u64,
        name: vector<u8>,
    }

    /*
        Holds data about a user team
    */
    struct Team has key, store {
        id: u64,
        owner: address,
        player1_id: u64,
        player2_id: u64,
        player3_id: u64,
        points: u64,
        rank: u64,
        is_reward_claimed: bool,
    }

    /*
        Holds data about event handlers
    */
    struct Event has store {
        create_team_events: EventHandle<CreateTeamEvent>,
        announce_result_events: EventHandle<AnnounceResultEvent>,
        claim_reward_events: EventHandle<ClaimRewardEvent>,
    }

    /////////////////////////////
    // FUNCTIONS // EDIT THESE //
    /////////////////////////////

    /*
        Creates a PDA and initializes State resource
        @param admin - signer of the admin account
    */
    public entry fun init(admin: &signer) {
        // TODO: Assert the signer is the admin
        assert_signer_is_admin(admin);

        // TODO: Create resource account
        let (resource_signer, sign_cap) = account::create_resource_account(admin,SEED);

        // TODO: Register AptosCoin to resource
        coin::register<AptosCoin>(&resource_signer);

        // TODO: Create player_list from PLAYER_NAMES with incrementing ids
        let player_list = vector::empty();
        let i = 0;
        while (i < vector::length(&PLAYER_NAMES)) {
            let player = Player {
                id: i,
                name: *vector::borrow(&PLAYER_NAMES,i),
            };
            vector::push_back<Player>(&mut player_list,move player);
            i = move i + 1;
        };

        // TODO: Create State instance and move it to the admin
        let instance = State {
            cap: move sign_cap,
            player_list: move player_list,
            team_list: vector::empty(),
            is_result_announced: false,
            events: Event {
                create_team_events: account::new_event_handle<CreateTeamEvent>(admin),
                announce_result_events: account::new_event_handle<AnnounceResultEvent>(admin),
                claim_reward_events: account::new_event_handle<ClaimRewardEvent>(admin),
            }
        };
        move_to<State>(move admin,move instance);
    }

    /*
        Creates a new football fantasy team with 3 players.
        @param account - account, which will own the team
        @param player1_id - id of the first player
        @param player2_id - id of the second player
        @param player3_id - id of the third player
    */
    public entry fun create_team(
        account: &signer,
        player1_id: u64,
        player2_id: u64,
        player3_id: u64,
    ) acquires State {
        // TODO: Assert that state is initialized
        assert_state_initialized();

        // TODO: Assert that the result is not announced yet
        assert_result_not_announced();

        // TODO: Assert that all players exist
        assert_player_exists(player1_id);
        assert_player_exists(player2_id);
        assert_player_exists(player3_id);

        // TODO: Assert that there is no any duplicated player_id
        assert_no_duplicated_player_id(player1_id, player2_id, player3_id);

        // TODO: Register AptosCoin in case the team win some reward
        coin::register<AptosCoin>(account);

        // TODO: Create a team and add to State , use 0 as default for points and rank
        let instance = borrow_global_mut<State>(@admin);
        let next_team_id = vector::length(&instance.team_list);
        let team = Team {
            id: next_team_id,
            owner: signer::address_of(account),
            player1_id,
            player2_id,
            player3_id,
            points: 0,
            rank: 0,
            is_reward_claimed: false,
        };
        vector::push_back(&mut instance.team_list, move team);

        // TODO: Emit CreateTeamEvent event
        event::emit_event<CreateTeamEvent>(
            &mut instance.events.create_team_events,
            rtmtree::foot_fantasy_events::new_create_team_event(
                signer::address_of(move account),
                move next_team_id,
                move player1_id,
                move player2_id,
                move player3_id,
                timestamp::now_seconds()
            )
        );
        move instance;
    }

    /*
        Announces the result of a match and updates the points and ranks of each team.
        @param admin - admin, who announces the result
        @param player_goals - vector of goals scored by each player_id in order
        @param player_assists - vector of assists made by each player_id in order
    */
    public entry fun announce_with_stats(
        admin: &signer,
        player_goals: vector<u64>,
        player_assists: vector<u64>
    ) acquires State {
        // TODO: Assert that state is initialized
        assert_state_initialized();

        // TODO: Assert the signer is the admin
        assert_signer_is_admin(admin);

        // TODO: Assert that the result is not announced yet
        assert_result_not_announced();

        // TODO: For all teams in team_list
        //      1. calculate the team's point
        //      2. update the team's point
        //      3. update the team's rank
        //          if points are equal, consider the team with lower team_id as higher rank (the team is created earlier)
        //      4. emit AnnounceResultEvent event
        let instance = borrow_global_mut<State>(@admin);

        //calculate and update points
        let i = 0;
        while (i < vector::length(&instance.team_list)) {
            let team = vector::borrow_mut(&mut instance.team_list, i);
            let player1_goal = vector::borrow(&player_goals, team.player1_id);
            let player2_goal = vector::borrow(&player_goals, team.player2_id);
            let player3_goal = vector::borrow(&player_goals, team.player3_id);
            let player1_assist = vector::borrow(&player_assists, team.player1_id);
            let player2_assist = vector::borrow(&player_assists, team.player2_id);
            let player3_assist = vector::borrow(&player_assists, team.player3_id);
            let team_goal_vec = vector[
                *player1_goal,
                *player2_goal,
                *player3_goal
            ];
            let team_assist_vec = vector[
                *player1_assist,
                *player2_assist,
                *player3_assist
            ];

            let points = calculate_points_from_stats(&team_goal_vec, &team_assist_vec);
            team.points = *vector::borrow(&points,0) + *vector::borrow(&points,1) + *vector::borrow(&points,2);
            i = move i + 1;
        };

        //update ranks
        let i = 0;
        while (i < vector::length(&instance.team_list)) {
            let team = vector::borrow(&instance.team_list, i);
            let j = 0;
            let teams_with_higher_points = 0;//0 means no team with higher points
            while (j < vector::length(&instance.team_list)) {
                let team2 = vector::borrow(&instance.team_list, j);
                if (team.points < team2.points) {
                    teams_with_higher_points = teams_with_higher_points + 1;
                } else if (team.points == team2.points && team.id > team2.id) {
                    // team.id > team2.id means team2 is created earlier
                    teams_with_higher_points = teams_with_higher_points + 1;
                };
                j = move j + 1;
            };
            let team = vector::borrow_mut(&mut instance.team_list, i);
            team.rank = teams_with_higher_points + 1;//+1 because the 1st team has rank 1 and so on
            i = move i + 1;
        };

        //emit AnnounceResultEvent event
        event::emit_event<AnnounceResultEvent>(
            &mut instance.events.announce_result_events,
            rtmtree::foot_fantasy_events::new_announce_result_event(
                player_goals,
                player_assists,
                timestamp::now_seconds()
            )
        );

        // TODO: Set is_result_announced to true
        instance.is_result_announced = true;
        move instance;
    }

    /*
        Calculates points for each player based on goals and assists
        @param player_goals - vector of goals scored by each player_id in order
        @param player_assists - vector of assists made by each player_id in order
        @returns - list of points for each player
    */
    inline fun calculate_points_from_stats(player_goals: &vector<u64>, player_assists: &vector<u64>): vector<u64> {
        // TODO: Assert that a length if player_goals is equal to a length of player_assists
        assert_vectors_have_equal_length<u64, u64>(player_goals, player_assists);

        // TODO: loop all players and calculate points for each player
        let i = 0;
        let player_points = vector::empty();
        while (i < vector::length(player_goals)) {
            // calculate points for each player
            let points = (*vector::borrow(player_goals,i) * POINT_PER_GOAL) + (*vector::borrow(
                player_assists,
                i
            ) * POINT_PER_ASSIST);
            vector::push_back(&mut player_points, move points);

            i = move i + 1;
        };
        player_points
    }

    public entry fun claim_reward(
        account: &signer,
        team_id: u64,
    ) acquires State {
        // TODO: Assert that state is initialized
        assert_state_initialized();

        // TODO: Assert that the result is announced
        assert_result_is_announced();

        // TODO: Assert that this team_id is not claimed yet
        assert_reward_is_not_claimed(team_id);

        // TODO: Mark that this team is already claimed
        let instance = borrow_global_mut<State>(@admin);
        let team = vector::borrow_mut(&mut instance.team_list, team_id);
        team.is_reward_claimed = true;

        // TODO: Get how much reward this team should get
        let reward = 0;
        let rank = team.rank;
        if (rank >= 1 && rank <=10){
            reward = REWARD_TOP10;
        };

        // TODO: Transfer reward if reward is more than 0
        // , assert that there is enough reward in the resource with `assert_contract_has_enought_apt` beforehand
        // TODO: Emit ClaimRewardEvent event
        if (reward > 0){
            let resource_signer = &account::create_signer_with_capability(&instance.cap);
            assert_contract_has_enought_apt(signer::address_of(resource_signer),REWARD_TOP10);

            coin::transfer<AptosCoin>(resource_signer, signer::address_of(account), reward);
            event::emit_event(
                &mut instance.events.claim_reward_events,
                rtmtree::foot_fantasy_events::new_claim_reward_event(
                    signer::address_of(account),
                    team_id,
                    move reward,
                    timestamp::now_seconds()
                )
            );
        };

    }

    ///////////////////////////
    // ASSERTS // EDIT THESE //
    ///////////////////////////

    inline fun assert_signer_is_admin(admin: &signer) {
        // TODO: Assert that address of the parameter is the same as admin in Move.toml
        assert!(signer::address_of(move admin) == @admin, ERROR_SIGNER_NOT_ADMIN);
    }

    inline fun assert_state_initialized() {
        // TODO: Assert that State resource exists at the admin address
        assert!(exists<State>(@admin), ERROR_STATE_NOT_INITIALIZED);
    }

    inline fun assert_player_exists(player_id: u64) acquires State {
        // TODO: Assert that player_list in State has length more than player_id
        let instance = borrow_global_mut<State>(@admin);
        assert!(vector::length(&instance.player_list) > move player_id, ERROR_PLAYER_DOES_NOT_EXIST);
    }

    inline fun assert_vectors_have_equal_length<T, U>(vector1: &vector<T>, vector2: &vector<U>) {
        assert!(vector::length(move vector1) == vector::length(move vector2), ERROR_LENGTHS_NOT_EQUAL);
    }

    inline fun assert_no_duplicated_player_id(player1_id: u64, player2_id: u64, player3_id: u64) {
        // TODO: Assert that player1_id, player2_id and player3_id are different
        assert!(
            player1_id != player2_id && player1_id != player3_id && player2_id != player3_id,
            ERROR_DUPLICATE_PLAYER_ID
        );
    }

    inline fun assert_result_not_announced() acquires State {
        // TODO: Assert that is_result_announced in State is false
        let instance = borrow_global_mut<State>(@admin);
        assert!(!instance.is_result_announced, ERROR_RESULT_ALREADY_ANNOUNCED);
    }

    inline fun assert_result_is_announced() acquires State {
        // TODO: Assert that is_result_announced in State is false
        let instance = borrow_global_mut<State>(@admin);
        assert!(instance.is_result_announced, ERROR_RESULT_IS_NOT_ANNOUNCED);
    }

    inline fun assert_reward_is_not_claimed(team_id: u64) acquires State {
        // TODO: Assert that is_reward_claimed of this team_id is false
        let instance = borrow_global_mut<State>(@admin);
        assert!(!vector::borrow(&instance.team_list, move team_id).is_reward_claimed, ERROR_REWARD_IS_ALREADY_CLAIMED);
    }

    inline fun assert_contract_has_enought_apt(resource_account_address: address ,minimum_balance: u64) {
        assert!(coin::balance<AptosCoin>(resource_account_address) >= minimum_balance, ERROR_NOT_ENOUGH_BALANCE_TO_REWARD);
    }

    ////////////////////////////
    // TESTS //// DO NOT EDIT //
    ////////////////////////////


    #[test]
    fun test_init() acquires State {
        let admin = account::create_account_for_test(@admin);
        init(&admin);

        let state = borrow_global<State>(@admin);
        assert!(vector::borrow(&state.player_list, 0).id == 0, 0);
        assert!(vector::borrow(&state.player_list, 0).name == b"Salah", 1);
        assert!(vector::borrow(&state.player_list, 1).id == 1, 2);
        assert!(vector::borrow(&state.player_list, 1).name == b"Rashford", 3);
        assert!(vector::borrow(&state.player_list, 2).id == 2, 4);
        assert!(vector::borrow(&state.player_list, 2).name == b"Bruno Fernandes", 5);
        assert!(vector::borrow(&state.player_list, 3).id == 3, 6);
        assert!(vector::borrow(&state.player_list, 3).name == b"De Bruyne", 7);
        assert!(vector::borrow(&state.player_list, 4).id == 4, 8);
        assert!(vector::borrow(&state.player_list, 4).name == b"Trent", 9);
        assert!(vector::borrow(&state.player_list, 5).id == 5, 10);
        assert!(vector::borrow(&state.player_list, 5).name == b"Maquire", 11);

        let resource_account_address = account::create_resource_address(&@admin, SEED);
        assert!(&state.cap == &account::create_test_signer_cap(resource_account_address), 10);
    }

    #[test]
    fun test_create_team() acquires State {
        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        let admin = account::create_account_for_test(@admin);
        init(&admin);

        let account = account::create_account_for_test(@0xCAFE);
        let player1_id = 0;
        let player2_id = 1;
        let player3_id = 2;
        create_team(&account, player1_id, player2_id, player3_id);

        let state = borrow_global<State>(@admin);
        assert!(vector::length(&state.team_list) == 1,0);
        assert!(vector::borrow(&state.team_list, 0).id == 0,1);
        assert!(vector::borrow(&state.team_list, 0).player1_id == 0,1);
        assert!(vector::borrow(&state.team_list, 0).player2_id == 1,2);
        assert!(vector::borrow(&state.team_list, 0).player3_id == 2,3);
        assert!(event::counter(&state.events.create_team_events) == 1, 4);

    }

    #[test]
    #[expected_failure(abort_code = ERROR_STATE_NOT_INITIALIZED, location = Self)]
    fun test_create_team_state_not_initalized() acquires State {
        let account = account::create_account_for_test(@0xCAFE);
        let player1_id = 0;
        let player2_id = 1;
        let player3_id = 2;
        create_team(&account, player1_id, player2_id, player3_id);
    }

    #[test]
    #[expected_failure(abort_code = ERROR_PLAYER_DOES_NOT_EXIST, location = Self)]
    fun test_create_team_player_not_exist() acquires State {
        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        let admin = account::create_account_for_test(@admin);
        init(&admin);

        let account = account::create_account_for_test(@0xCAFE);
        let player1_id = 0;
        let player2_id = 1;
        let player3_id = 9;
        create_team(&account, player1_id, player2_id, player3_id);
    }

    #[test]
    #[expected_failure(abort_code = ERROR_DUPLICATE_PLAYER_ID, location = Self)]
    fun test_create_team_player_duplicated() acquires State {
        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        let admin = account::create_account_for_test(@admin);
        init(&admin);

        let account = account::create_account_for_test(@0xCAFE);
        let player1_id = 0;
        let player2_id = 1;
        let player3_id = 1;
        create_team(&account, player1_id, player2_id, player3_id);
    }

    #[test]
    fun test_create_teams() acquires State {
        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        let admin = account::create_account_for_test(@admin);
        init(&admin);

        let account = account::create_account_for_test(@0xCAFE);
        let player1_id = 0;
        let player2_id = 1;
        let player3_id = 2;
        create_team(&account, player1_id, player2_id, player3_id);
        let account = account::create_account_for_test(@0xDAD);
        let player1_id = 0;
        let player2_id = 2;
        let player3_id = 3;
        create_team(&account, player1_id, player2_id, player3_id);
        let account = account::create_account_for_test(@0xC0FFEE);
        let player1_id = 3;
        let player2_id = 4;
        let player3_id = 5;
        create_team(&account, player1_id, player2_id, player3_id);
        let player1_id = 3;
        let player2_id = 4;
        let player3_id = 5;
        create_team(&account, player1_id, player2_id, player3_id);

        let state = borrow_global<State>(@admin);
        assert!(vector::length(&state.team_list) == 4,0);
        assert!(vector::borrow(&state.team_list, 0).id == 0,1);
        assert!(vector::borrow(&state.team_list, 0).player1_id == 0,2);
        assert!(vector::borrow(&state.team_list, 0).player2_id == 1,3);
        assert!(vector::borrow(&state.team_list, 0).player3_id == 2,4);
        assert!(vector::borrow(&state.team_list, 1).id == 1,5);
        assert!(vector::borrow(&state.team_list, 1).player1_id == 0,6);
        assert!(vector::borrow(&state.team_list, 1).player2_id == 2,7);
        assert!(vector::borrow(&state.team_list, 1).player3_id == 3,8);
        assert!(vector::borrow(&state.team_list, 2).id == 2,9);
        assert!(vector::borrow(&state.team_list, 2).player1_id == 3,10);
        assert!(vector::borrow(&state.team_list, 2).player2_id == 4,11);
        assert!(vector::borrow(&state.team_list, 2).player3_id == 5,12);
        assert!(vector::borrow(&state.team_list, 3).id == 3,13);
        assert!(vector::borrow(&state.team_list, 3).player1_id == 3,14);
        assert!(vector::borrow(&state.team_list, 3).player2_id == 4,15);
        assert!(vector::borrow(&state.team_list, 3).player3_id == 5,16);
        assert!(event::counter(&state.events.create_team_events) == 4, 17);

    }

    #[test]
    fun test_announce() acquires State {
        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        let admin = account::create_account_for_test(@admin);
        init(&admin);

        let account = account::create_account_for_test(@0xCAFE);
        let player1_id = 0;
        let player2_id = 1;
        let player3_id = 2;
        create_team(&account, player1_id, player2_id, player3_id);
        let account = account::create_account_for_test(@0xDAD);
        let player1_id = 0;
        let player2_id = 2;
        let player3_id = 3;
        create_team(&account, player1_id, player2_id, player3_id);
        let account = account::create_account_for_test(@0xC0FFEE);
        let player1_id = 3;
        let player2_id = 4;
        let player3_id = 5;
        create_team(&account, player1_id, player2_id, player3_id);
        let player1_id = 3;
        let player2_id = 4;
        let player3_id = 5;
        create_team(&account, player1_id, player2_id, player3_id);

        let player_goals = vector[
            0,
            1,
            1,
            0,
            0,
            1,
        ];
        let player_assists = vector[
            1,
            1,
            0,
            0,
            1,
            1,
        ];
        announce_with_stats(&admin, player_goals, player_assists);

        let state = borrow_global<State>(@admin);
        assert!(vector::length(&state.team_list) == 4, 0);
        assert!(vector::borrow(&state.team_list, 0).points == 18, 1);
        assert!(vector::borrow(&state.team_list, 1).points == 9, 2);
        assert!(vector::borrow(&state.team_list, 2).points == 12, 3);
        assert!(vector::borrow(&state.team_list, 3).points == 12, 4);
        assert!(vector::borrow(&state.team_list, 0).rank == 1, 5);
        assert!(vector::borrow(&state.team_list, 1).rank == 4, 6);
        assert!(vector::borrow(&state.team_list, 2).rank == 2, 7);
        assert!(vector::borrow(&state.team_list, 3).rank == 3, 8);
        assert!(event::counter(&state.events.create_team_events) == 4, 9);
        assert!(event::counter(&state.events.announce_result_events) == 1, 10);
    }

    #[test]
    #[expected_failure(abort_code = ERROR_RESULT_ALREADY_ANNOUNCED, location = Self)]
    fun test_create_team_after_announced() acquires State {
        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        let admin = account::create_account_for_test(@admin);
        init(&admin);

        let account = account::create_account_for_test(@0xCAFE);
        let player1_id = 0;
        let player2_id = 1;
        let player3_id = 2;
        create_team(&account, player1_id, player2_id, player3_id);
        let account = account::create_account_for_test(@0xDAD);
        let player1_id = 0;
        let player2_id = 2;
        let player3_id = 3;
        create_team(&account, player1_id, player2_id, player3_id);
        let account = account::create_account_for_test(@0xC0FFEE);
        let player1_id = 3;
        let player2_id = 4;
        let player3_id = 5;
        create_team(&account, player1_id, player2_id, player3_id);
        let player1_id = 3;
        let player2_id = 4;
        let player3_id = 5;
        create_team(&account, player1_id, player2_id, player3_id);

        let player_goals = vector[
            0,
            1,
            1,
            0,
            0,
            1,
        ];
        let player_assists = vector[
            1,
            1,
            0,
            0,
            1,
            1,
        ];
        announce_with_stats(&admin, player_goals, player_assists);

        let player1_id = 3;
        let player2_id = 4;
        let player3_id = 5;
        create_team(&account, player1_id, player2_id, player3_id);
    }

    #[test]
    fun test_announce_no_team() acquires State {
        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        let admin = account::create_account_for_test(@admin);
        init(&admin);

        let player_goals = vector[
            0,
            1,
            1,
            0,
            0,
            1,
        ];
        let player_assists = vector[
            1,
            1,
            0,
            0,
            1,
            1,
        ];
        announce_with_stats(&admin, player_goals, player_assists);

        let state = borrow_global<State>(@admin);
        assert!(event::counter(&state.events.announce_result_events) == 1, 10);
    }

    #[test]
    #[expected_failure(abort_code = ERROR_LENGTHS_NOT_EQUAL, location = Self)]
    fun test_calculate_points_from_stats_length_not_equal() {
        let admin = account::create_account_for_test(@admin);
        init(&admin);

        let player_goals = vector[
            0,
            1,
            1,
            0,
            0,
            1,
        ];
        let player_assists = vector[
            1,
            1,
            0,
            0,
            1,
            0,
            0,
            0,
        ];

        let player_points = calculate_points_from_stats(&player_goals, &player_assists);
        assert!(*vector::borrow(&player_points, 0) == 3, 0);
        assert!(*vector::borrow(&player_points, 1) == 9, 1);
        assert!(*vector::borrow(&player_points, 2) == 6, 2);
        assert!(*vector::borrow(&player_points, 3) == 0, 3);
        assert!(*vector::borrow(&player_points, 4) == 3, 4);
        assert!(*vector::borrow(&player_points, 5) == 6, 5);
    }

    #[test]
    #[expected_failure(abort_code = ERROR_RESULT_ALREADY_ANNOUNCED, location = Self)]
    fun test_announce_double() acquires State {
        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        let admin = account::create_account_for_test(@admin);
        init(&admin);

        let player_goals = vector[
            0,
            1,
            1,
            0,
            0,
            1,
        ];
        let player_assists = vector[
            1,
            1,
            0,
            0,
            1,
            1,
        ];
        announce_with_stats(&admin, player_goals, player_assists);
        announce_with_stats(&admin, player_goals, player_assists);
    }

    #[test]
    fun test_claimed_top10_success() acquires State {

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        let (burn_cap, mint_cap) = aptos_coin::initialize_for_test(&aptos_framework);

        let admin = account::create_account_for_test(@admin);
        init(&admin);

        let resource_signer_address = account::create_resource_address(&signer::address_of(&admin),SEED);
        aptos_coin::mint(&aptos_framework, resource_signer_address, REWARD_TOP10 * 10);
        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);

        let account = account::create_account_for_test(@0xCAFE);
        let player1_id = 0;
        let player2_id = 1;
        let player3_id = 2;
        create_team(&account, player1_id, player2_id, player3_id);
        let account = account::create_account_for_test(@0xDAD);
        let player1_id = 0;
        let player2_id = 2;
        let player3_id = 3;
        create_team(&account, player1_id, player2_id, player3_id);
        let account = account::create_account_for_test(@0xC0FFEE);
        let player1_id = 3;
        let player2_id = 4;
        let player3_id = 5;
        create_team(&account, player1_id, player2_id, player3_id);
        let player1_id = 3;
        let player2_id = 4;
        let player3_id = 5;
        create_team(&account, player1_id, player2_id, player3_id);

        let player_goals = vector[
            0,
            1,
            1,
            0,
            0,
            1,
        ];
        let player_assists = vector[
            1,
            1,
            0,
            0,
            1,
            1,
        ];

        announce_with_stats(&admin, player_goals, player_assists);

        claim_reward(&account,3);
        assert!(coin::balance<AptosCoin>(signer::address_of(&account)) == REWARD_TOP10, 0);
        let state = borrow_global<State>(signer::address_of(&admin));
        assert!(event::counter(&state.events.claim_reward_events) == 1, 0);
    }

    #[test]
    #[expected_failure(abort_code = ERROR_REWARD_IS_ALREADY_CLAIMED, location = Self)]
    fun test_claimed_double() acquires State {

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        let (burn_cap, mint_cap) = aptos_coin::initialize_for_test(&aptos_framework);

        let admin = account::create_account_for_test(@admin);
        init(&admin);

        let resource_signer_address = account::create_resource_address(&signer::address_of(&admin),SEED);
        aptos_coin::mint(&aptos_framework, resource_signer_address, REWARD_TOP10 * 10);
        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);

        let account = account::create_account_for_test(@0xCAFE);
        let player1_id = 0;
        let player2_id = 1;
        let player3_id = 2;
        create_team(&account, player1_id, player2_id, player3_id);
        let account = account::create_account_for_test(@0xDAD);
        let player1_id = 0;
        let player2_id = 2;
        let player3_id = 3;
        create_team(&account, player1_id, player2_id, player3_id);
        let account = account::create_account_for_test(@0xC0FFEE);
        let player1_id = 3;
        let player2_id = 4;
        let player3_id = 5;
        create_team(&account, player1_id, player2_id, player3_id);
        let player1_id = 3;
        let player2_id = 4;
        let player3_id = 5;
        create_team(&account, player1_id, player2_id, player3_id);

        let player_goals = vector[
            0,
            1,
            1,
            0,
            0,
            1,
        ];
        let player_assists = vector[
            1,
            1,
            0,
            0,
            1,
            1,
        ];

        announce_with_stats(&admin, player_goals, player_assists);

        claim_reward(&account,3);
        claim_reward(&account,3);
    }

    #[test]
    fun test_claimed_not_in_top10_success() acquires State {

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        let (burn_cap, mint_cap) = aptos_coin::initialize_for_test(&aptos_framework);

        let admin = account::create_account_for_test(@admin);
        init(&admin);

        let resource_signer_address = account::create_resource_address(&signer::address_of(&admin),SEED);
        aptos_coin::mint(&aptos_framework, resource_signer_address, REWARD_TOP10 * 10);
        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);

        let account = account::create_account_for_test(@0xCAFE);
        let player1_id = 0;
        let player2_id = 1;
        let player3_id = 2;
        create_team(&account, player1_id, player2_id, player3_id);
        let account = account::create_account_for_test(@0xDAD);
        let player1_id = 0;
        let player2_id = 2;
        let player3_id = 3;
        create_team(&account, player1_id, player2_id, player3_id);
        let account = account::create_account_for_test(@0xC0FFEE);
        let player1_id = 3;
        let player2_id = 4;
        let player3_id = 5;
        create_team(&account, player1_id, player2_id, player3_id);
        let player1_id = 3;
        let player2_id = 4;
        let player3_id = 5;
        create_team(&account, player1_id, player2_id, player3_id);
        let player1_id = 3;
        let player2_id = 4;
        let player3_id = 5;
        create_team(&account, player1_id, player2_id, player3_id);
        let player1_id = 3;
        let player2_id = 4;
        let player3_id = 5;
        create_team(&account, player1_id, player2_id, player3_id);
        let player1_id = 3;
        let player2_id = 4;
        let player3_id = 5;
        create_team(&account, player1_id, player2_id, player3_id);
        let player1_id = 3;
        let player2_id = 4;
        let player3_id = 5;
        create_team(&account, player1_id, player2_id, player3_id);
        let player1_id = 3;
        let player2_id = 4;
        let player3_id = 5;
        create_team(&account, player1_id, player2_id, player3_id);
        let player1_id = 3;
        let player2_id = 4;
        let player3_id = 5;
        create_team(&account, player1_id, player2_id, player3_id);

        let not_win_account = account::create_account_for_test(@0xDEADBEEF);
        let player1_id = 0;
        let player2_id = 3;
        let player3_id = 4;
        create_team(&not_win_account, player1_id, player2_id, player3_id);

        let player_goals = vector[
            0,
            1,
            1,
            0,
            0,
            1,
        ];
        let player_assists = vector[
            1,
            1,
            0,
            0,
            1,
            1,
        ];

        announce_with_stats(&admin, player_goals, player_assists);

        claim_reward(&not_win_account,10);
        assert!(coin::balance<AptosCoin>(signer::address_of(&not_win_account)) == 0, 0);
        let state = borrow_global<State>(signer::address_of(&admin));
        assert!(event::counter(&state.events.claim_reward_events) == 0, 0);
    }

    #[test]
    #[expected_failure(abort_code = ERROR_RESULT_IS_NOT_ANNOUNCED, location = Self)]
    fun test_claimed_before_result_announced() acquires State {

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        let admin = account::create_account_for_test(@admin);
        init(&admin);

        let account = account::create_account_for_test(@0xCAFE);
        let player1_id = 0;
        let player2_id = 1;
        let player3_id = 2;
        create_team(&account, player1_id, player2_id, player3_id);
        let account = account::create_account_for_test(@0xDAD);
        let player1_id = 0;
        let player2_id = 2;
        let player3_id = 3;
        create_team(&account, player1_id, player2_id, player3_id);
        let account = account::create_account_for_test(@0xC0FFEE);
        let player1_id = 3;
        let player2_id = 4;
        let player3_id = 5;
        create_team(&account, player1_id, player2_id, player3_id);
        let player1_id = 3;
        let player2_id = 4;
        let player3_id = 5;
        create_team(&account, player1_id, player2_id, player3_id);

        claim_reward(&account,3);
    }
}