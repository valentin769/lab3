import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("Примена порака во позадина: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Joke App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<String> jokeTypes = [];
  List<Map<String, String>> favoriteJokes = [];

  @override
  void initState() {
    super.initState();
    fetchJokeTypes();
    setupPushNotifications();
    requestPermissionAndGetToken();
  }

  Future<void> fetchJokeTypes() async {
    final response = await http.get(Uri.parse('https://official-joke-api.appspot.com/types'));
    if (response.statusCode == 200) {
      setState(() {
        jokeTypes = List<String>.from(json.decode(response.body));
      });
    } else {
      throw Exception('Failed to load joke types');
    }
  }

  Future<void> setupPushNotifications() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("Received message: ${message.notification?.title}");
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print("Notification clicked: ${message.notification?.title}");
    });
  }

  Future<void> requestPermissionAndGetToken() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print("Корисникот дозволи нотификации");

      String? token = await messaging.getToken();
      print("FCM Token: $token");
    }
  }

  void addFavoriteJoke(Map<String, String> joke) {
    setState(() {
      favoriteJokes.add(joke);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Joke Types'),
      ),
      body: Column(
        children: [
          ElevatedButton.icon(
            icon: Icon(Icons.favorite, color: Colors.redAccent),
            label: Text('Favourites Jokes'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => FavoriteJokesScreen(favoriteJokes: favoriteJokes)),
              );
            },
          ),
          Expanded(
            child: ListView.builder(
              itemCount: jokeTypes.length,
              itemBuilder: (context, index) {
                return Card(
                  margin: EdgeInsets.all(10),
                  child: ListTile(
                    title: Text(jokeTypes[index]),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => JokeListScreen(
                            type: jokeTypes[index],
                            favoriteJokes: favoriteJokes,
                            addFavoriteJoke: addFavoriteJoke,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class JokeListScreen extends StatefulWidget {
  final String type;
  final List<Map<String, String>> favoriteJokes;
  final Function(Map<String, String>) addFavoriteJoke;

  JokeListScreen({required this.type, required this.favoriteJokes, required this.addFavoriteJoke});

  @override
  _JokeListScreenState createState() => _JokeListScreenState();
}

class _JokeListScreenState extends State<JokeListScreen> {
  List<dynamic> jokes = [];

  @override
  void initState() {
    super.initState();
    fetchJokes();
  }

  Future<void> fetchJokes() async {
    final response = await http.get(Uri.parse('https://official-joke-api.appspot.com/jokes/${widget.type}/ten'));
    if (response.statusCode == 200) {
      setState(() {
        jokes = json.decode(response.body);
      });
    } else {
      throw Exception('Failed to load jokes');
    }
  }

  void toggleFavorite(String setup, String punchline) {
    widget.addFavoriteJoke({'setup': setup, 'punchline': punchline});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.type} Jokes'),
      ),
      body: jokes.isEmpty
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
        itemCount: jokes.length,
        itemBuilder: (context, index) {
          return Card(
            margin: EdgeInsets.all(10),
            child: ListTile(
              title: Text(jokes[index]['setup']),
              subtitle: Text(jokes[index]['punchline']),
              trailing: IconButton(
                icon: Icon(Icons.favorite, color: Colors.redAccent),
                onPressed: () {
                  toggleFavorite(jokes[index]['setup'], jokes[index]['punchline']);
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class FavoriteJokesScreen extends StatelessWidget {
  final List<Map<String, String>> favoriteJokes;

  FavoriteJokesScreen({required this.favoriteJokes});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Favourites Jokes'),
      ),
      body: favoriteJokes.isEmpty
          ? Center(child: Text('No favorite jokes yet!'))
          : ListView.builder(
        itemCount: favoriteJokes.length,
        itemBuilder: (context, index) {
          return Card(
            margin: EdgeInsets.all(10),
            child: ListTile(
              title: Text(favoriteJokes[index]['setup']!),
              subtitle: Text(favoriteJokes[index]['punchline']!),
            ),
          );
        },
      ),
    );
  }
}
