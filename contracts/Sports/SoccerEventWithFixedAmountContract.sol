// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./libraries/SoccerEventLibrary.sol";

contract SoccerEventWithFixedAmountContract {

    struct ChampionshipInfo {
        uint256 id;
        string name;
    }

    struct EventInfo {
        string name;
        string homeTeam;
        string awayTeam;
        uint256 date;
        uint256 betAmount;
        uint256 totalBetAmount;
        uint256 championshipId;
        bool suspended;
    }

    struct SoccerBetWithFixedAmountInfo {
        uint256 eventId;
        address gambler;
        uint256 amount;
        SoccerEventLibrary.Result chosenResult;
        bool paid;
        bool isWinner;
    }

    address private owner;
    mapping(address => bool) private administrators;

    

    mapping(uint256 => SoccerEventLibrary.Championship) private championships;
    mapping(uint256 => SoccerEventLibrary.Event) private events;
    mapping(uint256 => SoccerEventLibrary.SoccerBetWithFixedAmount[]) private betsPerEvent;
    mapping(uint256 => SoccerEventLibrary.Result) private resultsFinalsByEvent;

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

    // Admins

    function addAdministrator(address _newAdministrator) external onlyOwner {
        administrators[_newAdministrator] = true;
        emit AdminAdded(_newAdministrator);
    }

    function removeAdministrator(address _administrator) external onlyOwner {
        require(_administrator != owner, "Cannot remove owner as administrator");
        administrators[_administrator] = false;
        emit AdministratorDeleted(_administrator);
    }

    function areYouAdmin() external view returns (bool){
        return administrators[msg.sender];
    }

    function getOwner() external view returns (address) {
        return owner;
    }

    // Championships

    function createChampionship(string memory _name) external onlyAdministrator {
        championshipCounter += 1;
        championships[championshipCounter] = SoccerEventLibrary.Championship({
            id: championshipCounter,
            name: _name
        });
    }

    function listChampionship() external view returns (ChampionshipInfo[] memory) {
        ChampionshipInfo[] memory campeonatos = new ChampionshipInfo[](championshipCounter);
        uint256 index = 0;
        for (uint256 i = 1; i <= championshipCounter; i++) {
            SoccerEventLibrary.Championship storage currentChampionship = championships[i];
            campeonatos[index] = ChampionshipInfo({
                name: currentChampionship.name,
                id: currentChampionship.id
            });
            index++;
        }

        return campeonatos;
    }

    function getChampionship(uint256 _championshipId) external view returns (ChampionshipInfo memory) {
        SoccerEventLibrary.Championship storage currentChampionship = championships[_championshipId];
        ChampionshipInfo memory currentChampionInfo = ChampionshipInfo({
            name: currentChampionship.name,
            id : currentChampionship.id
        });
        return currentChampionInfo;
    }

    // Events

    function createEvent(string memory _name, string memory _homeTeam, string memory _awayTeam, uint256 _date, uint256 _betAmount, uint256 _championshipId) external onlyAdministrator {
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

    function getEvent(uint256 _eventId) external view returns (EventInfo memory) {
        SoccerEventLibrary.Event storage eventCurrent = events[_eventId];
        EventInfo memory eventInfo = EventInfo({
            name: eventCurrent.name,
            homeTeam: eventCurrent.homeTeam,
            awayTeam: eventCurrent.awayTeam,
            date: eventCurrent.date,
            betAmount: eventCurrent.betAmount,
            totalBetAmount : eventCurrent.totalBetAmount,
            suspended:eventCurrent.suspended,
            championshipId: eventCurrent.championshipId
        });
        return eventInfo;
    }

    function suspendEvent(uint256 _eventId) external onlyAdministrator {
        events[_eventId].suspended = true;
    }

    function setFinalResult(uint256 _eventId, SoccerEventLibrary.Result _finalResult) external onlyAdministrator {
        require(_finalResult == SoccerEventLibrary.Result.Home || _finalResult == SoccerEventLibrary.Result.Draw || _finalResult == SoccerEventLibrary.Result.Away, "Result invalid");
        require(events[_eventId].suspended == false, "Event is suspended");
        require(block.timestamp > events[_eventId].date, "The result must be placed after the event date");
        resultsFinalsByEvent[_eventId] = _finalResult;
    }

    function eventIsAvailableToBet(uint256 _eventId) external view returns (bool) {
        SoccerEventLibrary.Event storage currentEvent = events[_eventId];
        return block.timestamp < currentEvent.date;
    }


    function getEventCount() external view returns (uint256) {
        return eventCounter;
    }

    function getEventCountByChampionship(uint256 _championshipId) external view returns (uint256) {
        uint256 counter = 0;
        for (uint256 i = 1; i <= eventCounter; i++) {
            if (_championshipId == events[i].championshipId) {
                counter++;
            }
        }
        return counter;
    }

    function getCurrentEvents() external view returns (EventInfo[] memory) {
        EventInfo[] memory eventsCurrent = new EventInfo[](eventCounter);

        uint256 index = 0;
        for (uint256 i = 1; i <= eventCounter; i++) {
            SoccerEventLibrary.Event storage currentEvent = events[i];
            if (block.timestamp < currentEvent.date) {
                
                eventsCurrent[index] = EventInfo({
                    name: currentEvent.name,
                    homeTeam: currentEvent.homeTeam,
                    awayTeam: currentEvent.awayTeam,
                    date: currentEvent.date,
                    betAmount: currentEvent.betAmount,
                    totalBetAmount: currentEvent.totalBetAmount,
                    championshipId: currentEvent.championshipId,
                    suspended: currentEvent.suspended
                });
                index++;
            }
        }

        return eventsCurrent;
    }

    function getCurrentEventsByChampionship(uint256 _championshipId) external view returns (EventInfo[] memory) {
        EventInfo[] memory eventsCurrent = new EventInfo[](eventCounter);
        uint256 index = 0;
        for (uint256 i = 1; i <= eventCounter; i++) {
            SoccerEventLibrary.Event storage currentEvent = events[i];
            if (block.timestamp < currentEvent.date && _championshipId == currentEvent.championshipId) {
                
                eventsCurrent[index] = EventInfo({
                    name: currentEvent.name,
                    homeTeam: currentEvent.homeTeam,
                    awayTeam: currentEvent.awayTeam,
                    date: currentEvent.date,
                    betAmount: currentEvent.betAmount,
                    totalBetAmount: currentEvent.totalBetAmount,
                    championshipId: currentEvent.championshipId,
                    suspended: currentEvent.suspended
                });
                index++;
            }
        }

        return eventsCurrent;
    }

    function getFinishedEvents() external view returns (EventInfo[] memory) {
        EventInfo[] memory finishedEvents = new EventInfo[](eventCounter);
        uint256 index = 0;
        for (uint256 i = 1; i <= eventCounter; i++) {
            SoccerEventLibrary.Event storage currentEvent = events[i];
            if (block.timestamp >= currentEvent.date) {
                
                finishedEvents[index] = EventInfo({
                    name: currentEvent.name,
                    homeTeam: currentEvent.homeTeam,
                    awayTeam: currentEvent.awayTeam,
                    date: currentEvent.date,
                    betAmount: currentEvent.betAmount,
                    totalBetAmount: currentEvent.totalBetAmount,
                    championshipId: currentEvent.championshipId,
                    suspended: currentEvent.suspended
                });
                index++;
            }
        }
        return finishedEvents;
    }

    function getFinishedEventsByChampionship(uint256 _championshipId) external view returns (EventInfo[] memory) {
        EventInfo[] memory finishedEvents = new EventInfo[](eventCounter);

        uint256 index = 0;
        for (uint256 i = 1; i <= eventCounter; i++) {
            SoccerEventLibrary.Event storage currentEvent = events[i];
            if (block.timestamp >= currentEvent.date && _championshipId == currentEvent.championshipId) {
                
                finishedEvents[index] = EventInfo({
                    name: currentEvent.name,
                    homeTeam: currentEvent.homeTeam,
                    awayTeam: currentEvent.awayTeam,
                    date: currentEvent.date,
                    betAmount: currentEvent.betAmount,
                    totalBetAmount: currentEvent.totalBetAmount,
                    championshipId: currentEvent.championshipId,
                    suspended: currentEvent.suspended
                });
                index++;
            }
        }

        return finishedEvents;
    }

    function getDepositedAmountPerEvent(uint256 _eventId) external view returns (uint256) {
        return events[_eventId].totalBetAmount;
    }

    //Bets

    function placeBet(uint256 _eventId, SoccerEventLibrary.Result _chosenResult) external payable {
        require(msg.value > 0, "The bet amount must be greater than zero");
        require(_chosenResult == SoccerEventLibrary.Result.Home || _chosenResult ==SoccerEventLibrary.Result.Draw || _chosenResult == SoccerEventLibrary.Result.Away, "Invalid result");
        require(block.timestamp < events[_eventId].date, "The bet must be placed before the event date");
        require(msg.value != events[_eventId].betAmount, "The bet must be for the specified amount");
        require(events[_eventId].suspended == false, "Event is suspended");

        SoccerEventLibrary.SoccerBetWithFixedAmount memory newBet = SoccerEventLibrary.SoccerBetWithFixedAmount({
            eventId: _eventId,
            gambler: msg.sender,
            amount: msg.value,
            chosenResult: _chosenResult,
            paid: false,
            isWinner: false
        });

        betsPerEvent[_eventId].push(newBet);
        events[_eventId].totalBetAmount += msg.value;

        emit BetPlaced(_eventId, msg.sender, msg.value, _chosenResult);
    }

    function getBetsByEvent(uint256 _eventId) external view returns (SoccerBetWithFixedAmountInfo[] memory) {
        uint256 countBetsByEvent = betsPerEvent[_eventId].length;
        SoccerBetWithFixedAmountInfo[] memory bets = new SoccerBetWithFixedAmountInfo[](countBetsByEvent);
        for (uint256 i = 0; i < countBetsByEvent; i++) {
            SoccerEventLibrary.SoccerBetWithFixedAmount storage currentBet = betsPerEvent[_eventId][i];
            bets[i] = SoccerBetWithFixedAmountInfo({
                eventId: currentBet.eventId,
                gambler: currentBet.gambler,
                amount: currentBet.amount,
                chosenResult: currentBet.chosenResult,
                paid: currentBet.paid,
                isWinner : currentBet.isWinner
            });
        }

        return bets;
    }

    

    function isWinner(uint256 _eventId, address _gambler) external view returns (bool) {
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
        uint256 countWinnersForPrize = countWinnersByEvent(_eventId);
        for (uint256 i = 0; i < betsPerEvent[_eventId].length; i++) {
            SoccerEventLibrary.SoccerBetWithFixedAmount storage currentBet = betsPerEvent[_eventId][i];

            if (currentBet.gambler == msg.sender && currentBet.chosenResult == resultsFinalsByEvent[_eventId] && !currentBet.paid) {
                uint256 individualPrize = amountTotalPrizes / countWinnersForPrize;
                currentBet.paid = true;
                currentBet.isWinner = true;
                payable(msg.sender).transfer(individualPrize);
                emit AwardClaimed(_eventId, msg.sender, individualPrize);
                return;
            }
        }

        revert("There is no prize available to claim.");
    }

    function countWinnersByEvent(uint256 _eventId) internal view returns (uint256) {
        uint256 counter = 0;

        for (uint256 i = 0; i < betsPerEvent[_eventId].length; i++) {
            if (betsPerEvent[_eventId][i].chosenResult == resultsFinalsByEvent[_eventId] && !betsPerEvent[_eventId][i].paid) {
                counter++;
            }
        }
        return counter;
    }
}
