import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:eating_timer/models/Timer.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  runApp(
    MaterialApp(debugShowCheckedModeBanner: false, home: const EatingTimer()),
  );
}

class EatingTimer extends StatefulWidget {
  const EatingTimer({super.key});

  @override
  State<EatingTimer> createState() => _EatingTimerState();
}

class _EatingTimerState extends State<EatingTimer> {
  List<ModelTimer> timers = [];
  Map<int, Timer> activeTimers = {};
  Map<int, double> originalTimers = {};
  late Database db;
  final TextEditingController titleController = TextEditingController();
  final TextEditingController durationController = TextEditingController();
  final AudioPlayer audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    initDb();
  }

  Future<void> initDb() async {
    db = await openDatabase(
      join(await getDatabasesPath(), 'timer_database.db'),
      onCreate: (db, version) {
        return db.execute('''
        CREATE TABLE timer(
        timerId INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT,
        duration REAL NOT NULL,
        isPaused INTEGER NOT NULL,
        elapsedTime REAL NOT NULL
        )
        ''');
      },
      version: 2,
    );
    readTimers();
  }

  //CRUD FUNCTIONS==========================================
  Future<void> addTimer() async {
    if (titleController.text.isEmpty || durationController.text.isEmpty) {
      clearFields();
      return;
    }
    final timer = ModelTimer(
      title: titleController.text,
      duration: double.parse(durationController.text),
      isPaused: true,
      elapsedTime: 0.0,
    );
    await db.insert(
      'timer',
      timer.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    clearFields();
    readTimers();
  }

  Future<void> readTimers() async {
    final List<Map<String, dynamic>> maps = await db.query('timer');
    setState(() {
      timers = maps.map((map) => ModelTimer.fromMap(map)).toList();
    });
  }

  Future<void> deleteTimer(int timerId) async {
    activeTimers[timerId]?.cancel();
    activeTimers.remove(timerId);
    await audioPlayer.stop();
    await db.delete('timer', where: 'timerId=?', whereArgs: [timerId]);
    readTimers();
  }

  Future<void> updateTimer(ModelTimer timer) async {
    await db.update(
      'timer',
      timer.toMap(),
      where: 'timerId = ?',
      whereArgs: [timer.timerId],
    );
    setState(() {
      int index = timers.indexWhere((t) => t.timerId == timer.timerId);
      if (index != -1) {
        timers[index] = timer;
      }
    });
  }

  void clearFields() {
    titleController.clear();
    durationController.clear();
  }

  @override
  void dispose() {
    for (var timer in activeTimers.values) {
      timer.cancel();
    }
    titleController.dispose();
    durationController.dispose();
    audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withBlue(30),
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.grey.shade800,
        title: Text(
          'Eating Timer',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 30,
          ),
        ),
      ),
      body: buildTimerGrid(),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.lightBlueAccent,
        onPressed: () => addTimerSheet(context),
        child: Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  //UI HELPER FUNCTIONS===================
  void playSound() {
    audioPlayer.play(AssetSource('audios/bell-ring.mp3'));
  }

  Widget buildTimerGrid() {
    if (timers.isEmpty) {
      return Center(
        child: Text(
          "No Timers Added",
          style: TextStyle(color: Colors.white, fontSize: 22),
        ),
      );
    }
    return GridView.builder(
      padding: EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 1,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.5,
      ),
      itemCount: timers.length,
      itemBuilder: (context, index) {
        return buildTimerCard(timers[index]);
      },
    );
  }

  Widget buildTimerCard(ModelTimer timer) {
    return Card(
      color: Colors.grey.shade800,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: EdgeInsets.all(15),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              timer.title,
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 30),
            Text(
              '${timer.duration.toInt()}',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 30,
              ),
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.lightBlue,
                  child: IconButton(
                    onPressed: () async {
                      if (timer.isPaused) {
                        final updatedTimer = ModelTimer(
                          timerId: timer.timerId,
                          title: timer.title,
                          duration: timer.duration,
                          isPaused: false,
                          elapsedTime: timer.elapsedTime,
                        );
                        await updateTimer(updatedTimer);
                        countdown(updatedTimer);
                      } else {
                        activeTimers[timer.timerId]?.cancel();
                        activeTimers.remove(timer.timerId);
                        final updatedTimer = ModelTimer(
                          timerId: timer.timerId,
                          title: timer.title,
                          duration: timer.duration,
                          isPaused: true,
                          elapsedTime: timer.elapsedTime,
                        );
                        await updateTimer(updatedTimer);
                      }
                    },
                    icon: Icon(
                      timer.isPaused ? Icons.play_arrow : Icons.pause,
                      color: Colors.white,
                    ),
                  ),
                ),
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.red,
                  child: IconButton(
                    onPressed: () async {
                      deleteTimer(timer.timerId!);
                    },
                    icon: Icon(Icons.delete, color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> addTimerSheet(BuildContext context) async {
    //Pops up when making a new timer
    await showGeneralDialog(
      barrierDismissible: true,
      context: context,
      barrierLabel: 'Dismiss',
      transitionDuration: Duration(milliseconds: 300),
      pageBuilder: (context, _, __) => Scaffold(
        backgroundColor: Colors.grey.shade800,
        body: sheetForm(context),
      ),
      transitionBuilder: (context, animation, _, child) => SlideTransition(
        position: Tween<Offset>(
          begin: Offset(0, -1),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }

  Widget sheetForm(BuildContext context) {
    return StatefulBuilder(
      builder: (context, _) {
        return Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white,
                    radius: 25,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.arrow_back,
                        color: Colors.lightBlue,
                        size: 30,
                      ),
                    ),
                  ),
                  SizedBox(width: 40),
                  Text(
                    'Add A New Timer',
                    style: TextStyle(
                      color: Colors.lightBlue,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 50),
              Center(
                child: Column(
                  children: [
                    TextField(
                      cursorColor: Colors.black,
                      controller: titleController,
                      style: TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white60,
                        labelText: 'Title',
                        labelStyle: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white, width: 2),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.lightBlue),
                        ),
                      ),
                    ),
                    SizedBox(height: 50),
                    TextField(
                      cursorColor: Colors.black,
                      controller: durationController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: Colors.white, fontSize: 22),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white60,
                        labelText: 'Seconds',
                        labelStyle: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white, width: 2),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.lightBlue),
                        ),
                      ),
                    ),
                    SizedBox(height: 25),
                    CircleAvatar(
                      backgroundColor: Colors.white,
                      radius: 25,
                      child: IconButton(
                        onPressed: () async {
                          await addTimer();
                          Navigator.pop(context);
                        },
                        icon: Icon(Icons.check, color: Colors.green, size: 30),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void countdown(ModelTimer timer) {
    if (activeTimers.containsKey(timer.timerId)) {
      return;
    }
    originalTimers.putIfAbsent(timer.timerId!, () => timer.duration);
    double currentDuration = timer.duration;
    activeTimers[timer.timerId!] = Timer.periodic(Duration(seconds: 1), (
      t,
    ) async {
      if (!activeTimers.containsKey(timer.timerId)) {
        t.cancel();
        return;
      }
      if (currentDuration <= 0) {
        currentDuration = originalTimers[timer.timerId]!;
        playSound();
        await updateTimer(
          ModelTimer(
            timerId: timer.timerId,
            title: timer.title,
            duration: originalTimers[timer.timerId]!,
            isPaused: false,
            elapsedTime: 0,
          ),
        );
      } else {
        currentDuration--;
        if (mounted) {
          setState(() {
            int index = timers.indexWhere((t) => t.timerId == timer.timerId);
            if (index != -1) {
              timers[index] = ModelTimer(
                timerId: timer.timerId,
                title: timer.title,
                duration: currentDuration,
                isPaused: timer.isPaused,
                elapsedTime: timer.elapsedTime,
              );
            }
          });
        }
      }
    });
  }
}
