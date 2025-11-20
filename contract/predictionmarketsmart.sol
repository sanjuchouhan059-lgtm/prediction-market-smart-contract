// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract PredictionMarket {
    struct Market {
        string description;
        uint256 deadline;
        bool resolved;
        uint8 outcome; // 0 = undecided, 1 = Yes, 2 = No
        mapping(uint8 => uint256) totalBets;
        mapping(address => mapping(uint8 => uint256)) userBets;
    }

    uint256 public marketCount;
    mapping(uint256 => Market) public markets;

    event MarketCreated(uint256 indexed marketId, string description, uint256 deadline);
    event BetPlaced(uint256 indexed marketId, address indexed user, uint8 outcome, uint256 amount);
    event MarketResolved(uint256 indexed marketId, uint8 outcome);

    /// @notice Create a prediction market
    function createMarket(string calldata _description, uint256 _deadline) external {
        require(_deadline > block.timestamp, "Deadline must be in the future");

        marketCount++;
        Market storage m = markets[marketCount];
        m.description = _description;
        m.deadline = _deadline;

        emit MarketCreated(marketCount, _description, _deadline);
    }

    /// @notice Place a bet on a specific market outcome
    function placeBet(uint256 _marketId, uint8 _outcome) external payable {
        require(msg.value > 0, "Bet amount required");
        require(_outcome == 1 || _outcome == 2, "Invalid outcome");

        Market storage m = markets[_marketId];
        require(block.timestamp < m.deadline, "Betting closed");

        m.totalBets[_outcome] += msg.value;
        m.userBets[msg.sender][_outcome] += msg.value;

        emit BetPlaced(_marketId, msg.sender, _outcome, msg.value);
    }

    /// @notice Resolve the market and declare winning outcome
    function resolveMarket(uint256 _marketId, uint8 _outcome) external {
        require(_outcome == 1 || _outcome == 2, "Invalid outcome");

        Market storage m = markets[_marketId];

        require(block.timestamp >= m.deadline, "Deadline not reached");
        require(!m.resolved, "Already resolved");

        m.resolved = true;
        m.outcome = _outcome;

        emit MarketResolved(_marketId, _outcome);
    }

    /// @notice Claim reward if user bet on the winning outcome
    function claimReward(uint256 _marketId) external {
        Market storage m = markets[_marketId];
        require(m.resolved, "Not resolved");

        uint8 winningOutcome = m.outcome;
        uint256 userBet = m.userBets[msg.sender][winningOutcome];
        require(userBet > 0, "No winning bet");

        uint256 totalWinningPool = m.totalBets[winningOutcome];
        uint256 totalLosingPool = m.totalBets[winningOutcome == 1 ? 2 : 1];

        // Reward = user's share of losing pool + original bet
        uint256 reward = userBet + (userBet * totalLosingPool) / totalWinningPool;

        // Reset user bet to prevent double claiming
        m.userBets[msg.sender][winningOutcome] = 0;

        payable(msg.sender).transfer(reward);
    }
}

