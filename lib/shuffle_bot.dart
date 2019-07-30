import 'dart:core';
import 'package:ShuffleBot/firebase_storage.dart';
import 'package:ShuffleBot/game.dart';

class ShuffleBot {

  static Future<String> startCommand(String chat_id, String sender) async {
    var text = "Hi, ${_formatName(sender)}\n\n"
    + "*This bot can help you to shuffle players to teams during tournament*\n\n" 
    + "`/create` - command which create new game. *Type* - required argument (*1x1* or *2x2*). It is type of your team by members count\n"
    + "`/shuffle` - command which create new *random* teams each time\n"
    + "`/add` - command which add new player\n"
    + "`/remove` - command which remove player\n"
    + "\n*Group chat features*\n\n"
    + "You can tap `/go` command which notify other members about coming event. Each of members can send *+* message which notify bot what "
    + "this member want join to coming event. After that user tap `/run` command with *type* argument and bot will create new game";

    await FirebaseStorage.createGame(chat_id, null);
    await FirebaseStorage.savePotentialPlayers(chat_id, []);

    return Future.value(text);
  }
  static Future<String> createCommand(String chat_id, String text) {
    var arguments = text.split(" ");

    if (arguments.length < 3) return Future.value("Failed arguments\n\nUse `/create type(*1x1* or *2x2*) players...`");

    var game = _parseGame(arguments.sublist(1));
    return FirebaseStorage.createGame(chat_id, game)
    .then((_) => 'New game was created. *${game.players.length}* players\n\nUse `/add` and `/remove` commands to edit count of players.');
  }

  static Future<String> shuffleCommand(String chat_id) {
    return FirebaseStorage.getGame(chat_id)
    .then((game) => game != null ? _formatShuffle(game.shuffle()) : "Please create game firstly\n\nUse `/create` command");
  }

  static Future<String> addCommand(String chat_id, String text) {
    var arguments = text.split(" ");

    if (arguments.length < 2) return Future.value("Illegal arguments\n\nUse `/add player`");

    var player_name = _removePrefixIfNeeded(arguments[1]);
    var player = Player(name: player_name);

    return FirebaseStorage.addPlayer(chat_id, player)
    .then((is_added)=> is_added ? "${_formatName(player_name)} was added" : "${_formatName(player_name)} already exist.");
  }

  static Future<String> removeCommand(String chat_id, String text) {
    var arguments = text.split(" ");

    if (arguments.length < 2) return Future.value("Illegal arguments\n\nUse `/remove player`");

    var player_name = arguments[1];
    var player = Player(name: player_name);

    return FirebaseStorage.removePlayer(chat_id, player)
    .then((is_removed) {
      if (is_removed) {
        return "${_formatName(player_name)} was removed.";
      } else {
        return "${_formatName(player_name)} not found :(";
      }
    });
  }

  static Future<String> goCommand(String chat_id, String sender) async {
    var player = Player(name: sender);
    await FirebaseStorage.savePotentialPlayers(chat_id, [player]);
    return "Please send *+* message to join";
  }

  static Future<String> runCommand(String chat_id, String text) async {
    var arguments = text.split(" ");

    if (arguments.length < 2) return Future.value("Failed arguments\n\nUse `/start type(`*1x1*` or `*2x2*`)`");

    var strategy_data = arguments[1];
    var players = await FirebaseStorage.getPotentialPlayers(chat_id);
    await FirebaseStorage.savePotentialPlayers(chat_id, []);

    var strategy = _parseStrategy(strategy_data);
    var game = Game(strategy, players);
    return FirebaseStorage.createGame(chat_id, game)
    .then((_) => 'New game was created. *${game.players.length}* players\n\nUse `/add` and `/remove` commands to edit count of players.');
  }

  static Future<String> currentCommand(String chat_id) {
    return FirebaseStorage.getGame(chat_id)
    .then((game) => game != null ? _formatGame(game) : "Can not find any game. Create one\n\nUse `/create` command");
  }

  static Future<String> plusKeyword(String chat_id, String sender) async {
    var player = Player(name: sender);
    await FirebaseStorage.addPotentialPlayer(chat_id, player);
    return null;
  }

  static int _parseStrategy(String strategy_data) {
    var strategy;
    switch (strategy_data) {
      case "1x1":
        strategy = 1;
        break;
      case "2x2":
        strategy = 2;
        break;
    }
    return strategy;
  }

  static String _formatStrategy(int strategy) {
    switch (strategy) {
      case 1 : return "1x1";
        break;
      case 2 : return "2x2";
        break;
    }

    return null;
  }

  static Game _parseGame(List<String> arguments) {
    var strategy_data = arguments[0];
    var players_data = arguments.sublist(1);

    var strategy = _parseStrategy(strategy_data);

    var players = players_data.map((name) => _removePrefixIfNeeded(name)).map((name) => Player(name: name)).toList();

    return Game(strategy, players);
  }

  static String _formatOpponents(Opponents opponents) {
    return _formatTeam(opponents.teams[0]) + " VS " + _formatTeam(opponents.teams[1]);
  }

  static String _formatTeam(Team team) {
    return _formatPlayers(team.players, " + ");
  }

  static String _formatPlayers(List<Player> players, String separator) {
    return players.map((player) => _formatName(player.name)).join(separator);
  }

  static String _formatName(String name) {
    return "*${_removePrefixIfNeeded(name)}*";
  }

  static String _removePrefixIfNeeded(String name) {
    if (name.isEmpty) return "";

    return name[0] == '@' ? name.substring(1) : name;
  }

  static String _formatGame(Game game) {
    var players = game.players.isNotEmpty ? _formatPlayers(game.players, ", ") : "empty";
    var players_text = "Players: $players";

    var strategy_text = "Strategy: *${_formatStrategy(game.strategy)}*";
    
    if (players_text.isEmpty && strategy_text.isEmpty) return null;

    if (strategy_text.isEmpty) return players_text;

    return "$players_text\n\n$strategy_text"; 
  }

  static String _formatShuffle(ShuffleResult result) {
    if (result == null || result.opponents.isEmpty) return "Can not create opponent pairs. Please add more players\n\nUse `/add` command to add player";

    var opponents = result
      .opponents
      .map((opponent) => _formatOpponents(opponent))
      .join("\n");

    var opponents_text = "Opponents\n" + opponents;

    if (result.losers.isEmpty) return opponents_text;

    var losers_text = "Wasted: ${_formatPlayers(result.losers, ", ")} :(";

    return opponents_text + "\n\n" + losers_text;
  }
}