import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mlg_app/device.dart';
import 'package:mlg_app/restopolis.dart';

class RestopolisSettings extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _RestopolisSettingState();
}

class _RestopolisSettingState extends State<RestopolisSettings> {
  List<int> selectedRestaurantIds = List.empty(growable: true);
  List<Map<String, dynamic>> availableRestaurants = List.empty(growable: true);
  Map<int, String> restaurantNames = {};
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

    final storage = FlutterSecureStorage();
    final service = RestopolisService();

    final savedIds = await storage.read(key: "restaurantIds");
    if (savedIds != null) {
      for(var id in savedIds.split(",").toList()) {
        if(id.isEmpty) continue;
        selectedRestaurantIds.add(int.tryParse(id) ?? 0);
      }
    } else {
      selectedRestaurantIds = List.empty(growable: true);
    }

    final sitesData = await service.getSitesAndRestaurants();
    availableRestaurants = List.empty(growable: true);

    for (var site in sitesData["objects"]) {
      for (var restaurant in site["restaurants"]) {
        availableRestaurants.add({
          "id": restaurant["id"],
          "name": restaurant["name"],
          "siteName": site["name"],
        });
        restaurantNames[restaurant["id"]] = restaurant["name"];
      }
    }

    setState(() {
      loading = false;
    });
  }

  Future<void> _saveRestaurants() async {
    final storage = FlutterSecureStorage();
    await storage.write(
      key: "restaurantIds",
      value: selectedRestaurantIds.join(','),
    );
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
              children: List.generate(selectedRestaurantIds.length + 1, (index) {
                if(index == selectedRestaurantIds.length) {
                  return ListTile(
                    leading: Icon(Icons.add),
                    title: Text("Add restaurant"),
                    onTap: () async {
                      var id = await showDialog<int>(context: context, builder: (context) {
                        List<Map<String, dynamic>> searchResults = List.empty(growable: true);

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
                                            String name = k["name"];
                                            String siteName = k["siteName"];
                                            if(name.toLowerCase().contains(text) || siteName.toLowerCase().contains(text)) {
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
                                            title: Text(searchResults[index]["name"]),
                                            onTap: () {
                                              Navigator.pop(context, searchResults[index]["id"]);
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
                      if(id != null) {
                        setState(() {
                          selectedRestaurantIds.add(id);
                          _saveRestaurants();
                        });
                      }
                    },
                  );
                }
                return ListTile(
                  title: Text(restaurantNames[selectedRestaurantIds[index]] ?? "Error"),
                  trailing: IconButton(
                    onPressed: () {
                      setState(() {
                        selectedRestaurantIds.removeAt(index);
                        _saveRestaurants();
                      });
                    },
                    icon: Icon(Icons.delete, color: Colors.redAccent),
                  ),
                );
              }),
            ),
            TextButton(
              onPressed: () {
                logout(context);
              },
              child: Center(
                child: Text(
                  "Log out",
                  style: TextStyle(color: Colors.redAccent)
                )
              ),
            )
          ],
        ),
      ),
    );
  }

  void logout(BuildContext context) async {
    var confirmed = await showDialog<bool>(context: context, builder: (context) {
      return AlertDialog(
        title: Text("Do you really want to sign out?"),
        actions: [
          TextButton(
            child: Text("Yes"),
            onPressed: () {
              Navigator.pop(context, true);
            },
          ),
          FilledButton(
            child: Text("No"),
            onPressed: () {
              Navigator.pop(context, false);
            },
          )
        ],
      );
    });
    if(confirmed == null) return;
    if(!confirmed) {
      return;
    }
    var storage = FlutterSecureStorage();
    await storage.delete(key: "loggedIn");
    var service = RestopolisService();
    var temp = await service.removeAccount(await storage.read(key: "customerId") ?? "", await DeviceIdService.getHardwareId());
    print(temp);
    Navigator.pop(context);
  }
}