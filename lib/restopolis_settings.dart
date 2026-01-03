import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:better_menu/restopolis.dart';

class RestopolisSettings extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _RestopolisSettingState();
}

class _RestopolisSettingState extends State<RestopolisSettings> {
  List<Restaurant> selectedRestaurants = List.empty(growable: true);
  List<Restaurant> availableRestaurants = List.empty(growable: true);
  bool loggedIn = false;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      loading = true;
    });

    selectedRestaurants = await RestaurantManager.getSelectedRestaurants();
    availableRestaurants = await RestaurantManager.getAllRestaurants();

    loggedIn = await UserManager.isLoggedIn();

    setState(() {
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Settings"),
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: Icon(Icons.arrow_back),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(selectedRestaurants.length + 1, (index) {
                if(index == selectedRestaurants.length) {
                  return ListTile(
                    leading: Icon(Icons.add),
                    title: Text("Add restaurant"),
                    onTap: () => selectRestaurant(),
                  );
                }
                return selectedRestaurantTile(index);
              }),
            ),
            if(loggedIn) logoutButton(context)
          ],
        ),
      ),
    );
  }

  void selectRestaurant() async {
    var restaurant = await showDialog<Restaurant>(
      context: context,
      builder: (context) {

      List<Restaurant> searchResults = List.empty(growable: true);

      return StatefulBuilder(builder: (context, setState) {
        return Dialog.fullscreen(
          child: Scaffold(
            appBar: AppBar(
              title: Text("Add restaurant"),
              leading: IconButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                icon: Icon(Icons.close),
              ),
            ),
            body: Padding(
              padding: const EdgeInsets.all(10.0),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      decoration: InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: "Search"
                      ),
                      onChanged: (text) {
                        searchResults = List.empty(growable: true);
                        for(var k in availableRestaurants) {
                          if(
                            (
                              k.name.toLowerCase().contains(text)
                                ||
                              k.siteName.toLowerCase().contains(text)
                            )
                              &&
                            !selectedRestaurants.contains(k)) {
                            searchResults.add(k);
                          }
                        }
                        setState(() {});
                      },
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(searchResults.length, (index) {
                        return ListTile(
                          title: Text(searchResults[index].name),
                          onTap: () {
                            Navigator.pop(context, searchResults[index]);
                          },
                        );
                      }),
                    )
                  ],
                ),
              ),
            ),
          ),
        );
      });
    });
    if(restaurant != null) {
      await RestaurantManager.selectRestaurant(restaurant);
      selectedRestaurants = await RestaurantManager.getSelectedRestaurants();
      setState(() {});
    }
  }

  ListTile selectedRestaurantTile(int index) {
    return ListTile(
      title: Text(selectedRestaurants[index].name),
      trailing: IconButton(
        onPressed: () async {
          await RestaurantManager.removeRestaurant(index);
          selectedRestaurants = await RestaurantManager.getSelectedRestaurants();
          setState(() {});
        },
        icon: Icon(Icons.delete, color: Colors.redAccent),
      ),
    );
  }

  TextButton logoutButton(BuildContext context) {
    return TextButton(
      onPressed: () {
        UserManager.logout(context);
      },
      child: Center(
        child: Text(
          "Log out",
          style: TextStyle(color: Colors.redAccent)
        )
      ),
    );
  }
}