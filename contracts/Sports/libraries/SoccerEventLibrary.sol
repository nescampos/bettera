// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library SoccerEventLibrary {
    enum Result {Home, Draw, Away}

    struct Championship {
        uint256 id;
        string name;
    }

    struct Event {
        string name;
        string homeTeam;
        string awayTeam;
        uint256 date;
        uint256 betAmount;
        uint256 totalBetAmount;
        uint256 championshipId;
        bool suspended;
    }

    struct SoccerBetWithFixedAmount {
        uint256 eventId;
        address gambler;
        uint256 amount;
        Result chosenResult;
        bool paid;
    }
}