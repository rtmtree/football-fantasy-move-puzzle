# Football Fantasy Coding  Puzzle in Move 

This is a coding puzzle related to a football fantasy game. The code is written in Move programming language.

## Puzzle Overview

This puzzle involves creating a smart contract for a football fantasy game.
The game is simple, each user can create a team of 3 players and the team
will get points based on the performance of the players in the real world.
The smart contract will be responsible for keeping data of the all teams.
After the match ended, admin come to put real-world result to the smart contract,
and the smart contract calculate score point for each team and also rank up all teams.

## Recommended Concepts

- Vector to store upgrades and read their properties
- Signer to manage State
- Timestamp to track time of all important events

## Puzzle Features

init():
- Create a signer capability of a resource account from the admin signer and a seed.
- Create a vector of football players from a global constant PLAYER_NAMES with incrementing player IDs.
- Save all of them in a global storage State.

create_team():
- Create a team with three unique player IDs with incrementing team IDs.
- Save the team data in the global storage State.
- Emit an event, CreateTeamEvent, to announce the details of this team creation.

announce_with_stats():
- Obtain football stats in the form of the number of goals and assists for each player ID as two vectors, player_goals and player_assists.
- Get the number of goals and assists for all players in each team and call calculate_points_from_stats to find out each player score points.
- Get the team score point by aggregate all players' score point.
- Calculate all teams' rank by sorting all teams score point in ascending order. Teams with equal score points will be considered the earlier submission as the higher rank.
- Save both the score point and rank of all teams in the global storage State.
- Emit an event, AnnounceResultEvent, to announce the details of the result announcement.

calculate_points_from_stats():
- Obtain football stats in the form of the number of goals and assists for each player ID as two vectors, player_goals and player_assists.
- Multiply the number of goals of each player with POINT_PER_GOAL.
- Multiply the number of assists of each player with POINT_PER_ASSIST.
- Calculate the total score point of each player by summing the player's multiplication of goals and assists together.
- Return a vector of all players' score point as a result

## Requirements

To run this code, you need to have Move programming language installed on your system along with Aptos CLI. You can download and install Move and Aptos CLI from their official websites.

## Test
To test the code, run the following command in your terminal:
```
aptos move test
```
This will execute all the test functions.

## How to ENJOY

The code is the finished and runnable version. If you want to play or explore more possible ways to implement, remove all code after `//TODO` in `/sources/core.move` and make a **MOVE** with your new ideas.

The steps are well explained with TODOs, function name and football fantasy logic.  Make a research about  football fantasy game if you are not accustomed to it.  🔥ENJOY CODING🔥
  
## Future Practice
More complex logic from the real-world version of Football Fantasy  can be implemented e.g.

 - Reward distribution
 - More player capacity per one team
 - Different point calculation for each position (Forward/ Midfielder/ Defender)

## Contributing
If you want to contribute to this project, feel free to fork the repository and submit a pull request with your changes.