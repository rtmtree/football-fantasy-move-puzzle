module rtmtree::foot_fantasy_events {

    struct CreateTeamEvent has store, drop {
        owner: address,
        team_id: u64,
        player1_id: u64,
        player2_id: u64,
        player3_id: u64,
        timestamp: u64
    }

    struct AnnounceResultEvent has store, drop {
        player_goals: vector<u64>,
        player_assists: vector<u64>,
        timestamp: u64
    }

    struct ClaimRewardEvent has store, drop {
        owner: address,
        team_id: u64,
        reward: u64,
        timestamp: u64
    }

    public fun new_create_team_event(
        owner: address,
        team_id: u64,
        player1_id: u64,
        player2_id: u64,
        player3_id: u64,
        timestamp: u64
    ): CreateTeamEvent {
        CreateTeamEvent {
            owner,
            team_id,
            player1_id,
            player2_id,
            player3_id,
            timestamp
        }
    }

    public fun new_announce_result_event(
        player_goals: vector<u64>,
        player_assists: vector<u64>,
        timestamp: u64
    ): AnnounceResultEvent {
        AnnounceResultEvent {
            player_goals,
            player_assists,
            timestamp
        }
    }

    public fun new_claim_reward_event(
        owner: address,
        team_id: u64,
        reward: u64,
        timestamp: u64
    ): ClaimRewardEvent {
        ClaimRewardEvent {
            owner,
            team_id,
            reward,
            timestamp
        }
    }

}