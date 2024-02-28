// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./libraries/SoccerEventLibrary.sol";

contract SoccerBetContract {
    address public owner;
    mapping(address => bool) public administrators;

    mapping(uint256 => SoccerEventLibrary.Championship) public championships;
    mapping(uint256 => SoccerEventLibrary.Event) public events;
    mapping(uint256 => SoccerEventLibrary.SoccerBetWithFixedAmount[]) public betsPerEvent;
    mapping(uint256 => SoccerEventLibrary.Result) public resultsFinalsByEvent;

    event BetPlaced(uint256 indexed eventId, address indexed gambler, uint256 amount, SoccerEventLibrary.Result result);
    event AwardClaimed(uint256 indexed eventId, address indexed gambler, uint256 prize);
    event AdminAdded(address administrator);
    event AdministratorDeleted(address administrator);

    uint256 private eventCounter;
    uint256 private championshipCounter;

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function");
        _;
    }

    modifier onlyAdministrator() {
        require(administrators[msg.sender], "Only administrators can call this function");
        _;
    }

    constructor() {
        owner = msg.sender;
        administrators[owner] = true;
        eventCounter = 0;
        championshipCounter = 0;
    }

    function addAdministrator(address _newAdministrator) external onlyOwner {
        administrators[_newAdministrator] = true;
        emit AdminAdded(_newAdministrator);
    }

    function removeAdministrator(address _administrator) external onlyOwner {
        require(_administrator != owner, "Cannot remove owner as administrator");
        administrators[_administrator] = false;
        emit AdministratorDeleted(_administrator);
    }

    function createChampionship(string memory _name) external onlyAdministrator {
        championshipCounter += 1;
        championships[championshipCounter] = SoccerEventLibrary.Championship({
            id: championshipCounter,
            name: _name
        });
    }

    function listChampionship() external view returns (SoccerEventLibrary.Championship[] memory) {
        SoccerEventLibrary.Championship[] memory campeonatos;

        for (uint256 i = 0; i < championshipCounter; i++) {
            campeonatos[i] = SoccerEventLibrary.Championship({
                name: championships[i].name,
                id: championships[i].id
            });
        }

        return campeonatos;
    }

    function crearEvent(string memory _name, string memory _homeTeam, string memory _awayTeam, uint256 _date, uint256 _betAmount, uint256 _championshipId) external onlyAdministrator {
        require(_betAmount > 0, "The bet amount must be greater than zero");
        eventCounter += 1;
        events[eventCounter] = SoccerEventLibrary.Event({
            name: _name,
            homeTeam: _homeTeam,
            awayTeam: _awayTeam,
            date: _date,
            betAmount: _betAmount,
            totalBetAmount : 0,
            suspended:false,
            championshipId: _championshipId
        });
    }

    function placeBet(uint256 _eventId, SoccerEventLibrary.Result _chosenResult) external payable {
        require(msg.value > 0, "The bet amount must be greater than zero");
        require(_chosenResult == SoccerEventLibrary.Result.Home || _chosenResult ==SoccerEventLibrary.Result.Draw || _chosenResult == SoccerEventLibrary.Result.Away, "Invalid result");
        require(block.timestamp < events[_eventId].date, "The bet must be placed before the event date");
        require(msg.value != events[_eventId].betAmount, "The bet must be for the specified amount");

        SoccerEventLibrary.SoccerBetWithFixedAmount memory newBet = SoccerEventLibrary.SoccerBetWithFixedAmount({
            eventId: _eventId,
            gambler: msg.sender,
            amount: msg.value,
            chosenResult: _chosenResult,
            paid: false
        });

        betsPerEvent[_eventId].push(newBet);
        events[_eventId].totalBetAmount += msg.value;

        emit BetPlaced(_eventId, msg.sender, msg.value, _chosenResult);
    }

    function suspendEvent(uint256 _eventId) external onlyAdministrator {
        events[_eventId].suspended = true;
    }

    function setFinalResult(uint256 _eventId, SoccerEventLibrary.Result _finalResult) external onlyAdministrator {
        require(_finalResult == SoccerEventLibrary.Result.Home || _finalResult == SoccerEventLibrary.Result.Draw || _finalResult == SoccerEventLibrary.Result.Away, "Resultado no valido");
        resultsFinalsByEvent[_eventId] = _finalResult;
    }

    function esGanador(uint256 _eventId, address _gambler) external view returns (bool) {
        for (uint256 i = 0; i < betsPerEvent[_eventId].length; i++) {
            SoccerEventLibrary.SoccerBetWithFixedAmount storage currentBet = betsPerEvent[_eventId][i];

            if (currentBet.gambler == _gambler && currentBet.chosenResult == resultsFinalsByEvent[_eventId] && !currentBet.paid) {
                return true;
            }
        }

        return false;
    }

    function recoverBetOnSuspendedEvent(uint256 _eventId) external {
        require(events[_eventId].suspended == true, "Event is not suspended");
        for (uint256 i = 0; i < betsPerEvent[_eventId].length; i++) {
            SoccerEventLibrary.SoccerBetWithFixedAmount storage currentBet = betsPerEvent[_eventId][i];

            if (currentBet.gambler == msg.sender && currentBet.chosenResult == resultsFinalsByEvent[_eventId] && !currentBet.paid) {
                uint256 individualPrize = currentBet.amount;
                currentBet.paid = true;
                payable(msg.sender).transfer(individualPrize);
                emit AwardClaimed(_eventId, msg.sender, individualPrize);
                return;
            }
        }

        revert("There is no amount available to claim.");
    }

    function claimPrize(uint256 _eventId) external {
        require(events[_eventId].suspended == false, "Event is suspended");
        uint256 amountTotalPrizes = events[_eventId].totalBetAmount;
        uint256 countWinnersForPrize = countWinners(_eventId);
        for (uint256 i = 0; i < betsPerEvent[_eventId].length; i++) {
            SoccerEventLibrary.SoccerBetWithFixedAmount storage currentBet = betsPerEvent[_eventId][i];

            if (currentBet.gambler == msg.sender && currentBet.chosenResult == resultsFinalsByEvent[_eventId] && !currentBet.paid) {
                uint256 individualPrize = amountTotalPrizes / countWinnersForPrize;
                currentBet.paid = true;
                payable(msg.sender).transfer(individualPrize);
                emit AwardClaimed(_eventId, msg.sender, individualPrize);
                return;
            }
        }

        revert("There is no prize available to claim.");
    }

    function countWinners(uint256 _eventId) internal view returns (uint256) {
        uint256 counter = 0;

        for (uint256 i = 0; i < betsPerEvent[_eventId].length; i++) {
            if (betsPerEvent[_eventId][i].chosenResult == resultsFinalsByEvent[_eventId] && !betsPerEvent[_eventId][i].paid) {
                counter++;
            }
        }

        return counter;
    }

    function getDepositedAmountPerEvent(uint256 _eventId) external view returns (uint256) {
        return events[_eventId].totalBetAmount;
    }

    function getEventCount() external view returns (uint256) {
        return eventCounter;
    }

    function getEventCountByChampionship(uint256 _championshipId) external view returns (uint256) {
        uint256 counter = 0;
        for (uint256 i = 0; i < eventCounter; i++) {
            if (_championshipId == events[i].championshipId) {
                counter++;
            }
        }
        return counter;
    }

    function getCurrentEvents() external view returns (SoccerEventLibrary.Event[] memory) {
        SoccerEventLibrary.Event[] memory eventsCurrent;

        for (uint256 i = 0; i < eventCounter; i++) {
            if (block.timestamp < events[i].date) {
                eventsCurrent[i] = SoccerEventLibrary.Event({
                    name: events[i].name,
                    homeTeam: events[i].homeTeam,
                    awayTeam: events[i].awayTeam,
                    date: events[i].date,
                    betAmount: events[i].betAmount,
                    totalBetAmount: events[i].totalBetAmount,
                    championshipId: events[i].championshipId,
                    suspended: events[i].suspended
                });
            }
        }

        return eventsCurrent;
    }

    function getCurrentEventsByChampionship(uint256 _championshipId) external view returns (SoccerEventLibrary.Event[] memory) {
        SoccerEventLibrary.Event[] memory eventsCurrent;

        for (uint256 i = 0; i < eventCounter; i++) {
            if (block.timestamp < events[i].date && _championshipId == events[i].championshipId) {
                eventsCurrent[i] = SoccerEventLibrary.Event({
                    name: events[i].name,
                    homeTeam: events[i].homeTeam,
                    awayTeam: events[i].awayTeam,
                    date: events[i].date,
                    betAmount: events[i].betAmount,
                    totalBetAmount: events[i].totalBetAmount,
                    championshipId: events[i].championshipId,
                    suspended: events[i].suspended
                });
            }
        }

        return eventsCurrent;
    }

    function getFinishedEvents() external view returns (SoccerEventLibrary.Event[] memory) {
        SoccerEventLibrary.Event[] memory finishedEvents;

        for (uint256 i = 0; i < eventCounter; i++) {
            if (block.timestamp >= events[i].date) {
                finishedEvents[i] = SoccerEventLibrary.Event({
                    name: events[i].name,
                    homeTeam: events[i].homeTeam,
                    awayTeam: events[i].awayTeam,
                    date: events[i].date,
                    betAmount: events[i].betAmount,
                    totalBetAmount: events[i].totalBetAmount,
                    championshipId: events[i].championshipId,
                    suspended: events[i].suspended
                });
            }
        }

        return finishedEvents;
    }

    function getFinishedEventsByChampionship(uint256 _championshipId) external view returns (SoccerEventLibrary.Event[] memory) {
        SoccerEventLibrary.Event[] memory finishedEvents;

        for (uint256 i = 0; i < eventCounter; i++) {
            if (block.timestamp >= events[i].date && _championshipId == events[i].championshipId) {
                finishedEvents[i] = SoccerEventLibrary.Event({
                    name: events[i].name,
                    homeTeam: events[i].homeTeam,
                    awayTeam: events[i].awayTeam,
                    date: events[i].date,
                    betAmount: events[i].betAmount,
                    totalBetAmount: events[i].totalBetAmount,
                    championshipId: events[i].championshipId,
                    suspended: events[i].suspended
                });
            }
        }

        return finishedEvents;
    }
}
