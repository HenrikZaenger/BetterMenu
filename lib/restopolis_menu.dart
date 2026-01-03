import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:better_menu/restopolis.dart';
import 'package:better_menu/restopolis_settings.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';

class RestopolisMenu extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _RestopolisMenuState();
}

class _RestopolisMenuState extends State<RestopolisMenu> {

  Map<String, dynamic> account = {};
  int slider = 25;
  bool loading = true;
  bool loggedIn = false;
  Map<Restaurant, Menu> menus = {};
  DateTime date = DateTime.now();

  @override
  void initState() {
    super.initState();
    fetchMenuData();
  }

  Future<void> fetchMenuData() async {

    loading = true;

    loggedIn = await UserManager.isLoggedIn();

    menus = await MenuManager.getMenuForDate(date);

    setState(() {
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Menu - ${date.day}.${date.month}.${date.year}"),
        elevation: 3,
        actions: [
          IconButton(
            onPressed: () {
              date = date.subtract(Duration(days: 1));
              setState(() {
                fetchMenuData();
              });
            },
            icon: Icon(Icons.arrow_back_ios),
          ),
          IconButton(
            onPressed: () {
              date = date.add(Duration(days: 1));
              setState(() {
                fetchMenuData();
              });
            },
            icon: Icon(Icons.arrow_forward_ios),
          ),
          IconButton(
            onPressed: () {
              _openSettings();
            },
            icon: Icon(Icons.settings),
          )
        ],
      ),
      floatingActionButton: loading ? null : FloatingActionButton.extended(
        onPressed: loggedIn ? () {
          var bottomSheet = showModalBottomSheet(
            context: context,
            showDragHandle: true,
            builder: (context) {
              return StatefulBuilder(
                builder: (context, setModalState) => Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "$slider",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 26
                            ),
                          )
                        ],
                      ),
                      Slider(
                        padding: EdgeInsets.all(0),
                        min: 5,
                        max: 100,
                        divisions: 19,
                        value: slider.toDouble(),
                        year2023: false,
                        allowedInteraction: SliderInteraction.tapAndSlide,
                        onChanged: (value) {
                          setModalState(() {
                            slider = value.truncate();
                          });
                          setState(() {
                            slider = value.truncate();
                          });
                        },
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("5"),
                          Text("100")
                        ],
                      ),
                      SizedBox(
                        height: 10,
                      ),
                      Row(
                        spacing: 20,
                        children: [
                          Expanded(
                            child: FilledButton(
                              onPressed: () {
                                payconiq(slider);
                              },
                              child: Text("Payconiq")
                            ),
                          )
                        ],
                      ),
                      SizedBox(
                        height: 10,
                      ),
                    ],
                  ),
                ),
              );
            }
          );
          bottomSheet.then((value) {
            slider = 25;
          });
        } : () {
          showDialog(context: context, builder: (context) {
            return Dialog.fullscreen(
              semanticsRole: SemanticsRole.dialog,
              child: Column(
                mainAxisSize: .min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Column(
                      spacing: 10,
                      children: [
                        SizedBox(
                          height: 500,
                          child: MobileScanner(
                            onDetect: (data) {
                              login(data.barcodes.first.rawValue ?? "");
                              Navigator.pop(context);
                            },
                          ),
                        ),
                        Text("Please scan the qr code on your account page of the Restopolis Webiste!")
                      ],
                    ),
                  )
                ],
              ),
            );
          });
        },
        label: loggedIn ? Text("${account["objects"][0]["balance"]}€") : Text("LogIn"),
        icon: loggedIn ? Icon(Icons.add) : Icon(Icons.person),
      ),
      body: loading ? Center(child: CircularProgressIndicator(
        year2023: false,
      ))
      : Padding(
        padding: const EdgeInsets.all(10.0),
        child: SingleChildScrollView(
          child: Column(
            children: List.generate(menus.length, (restaurantIndex) {
              final menu = menus.entries.elementAt(restaurantIndex).value;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if(menu.gangs.isNotEmpty) Row(
                      spacing: 10,
                      children: [
                        Text(
                          menu.restaurant.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Expanded(child: Divider(
                          thickness: 2.5,
                          color: Theme.of(context).textTheme.headlineMedium?.color,
                        ))
                      ],
                    ),
                    Column(
                      children: List.generate(menu.gangs.length, (objectIndex) {
                        return Card(
                          child: ListTile(
                            title: Text(
                              "${menu.gangs[objectIndex].name}:",
                              style: TextStyle(
                                fontSize: Theme.of(context).textTheme.titleMedium?.fontSize,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(menu.gangs[objectIndex].products.length, (productIndex) {
                                return Text(
                                  menu.gangs[objectIndex].products[productIndex].name,
                                  textAlign: TextAlign.left,
                                );
                              }),
                            ),
                          ),
                        );
                      }),
                    )
                  ],
                );
              }
            ),
          ),
        ),
      ),
    );
  }

  void _openSettings() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => RestopolisSettings()));
    loading = true;
    fetchMenuData();
  }

  void login(String uri) async {
    if(!uri.startsWith("restopolis://register/")) {
      return;
    }
    var combined = uri.replaceFirst("restopolis://register/", "");
    var user = combined.split("/").first;
    var code = combined.split("/").last;
    var storage = FlutterSecureStorage();
    RestopolisApi service = RestopolisApi();
    var result = await service.pairAccount(username: user, key: code);
    if(result["code"] != 0) {
      return;
    }
    print(result);
    storage.write(key: "customerId", value: result["objects"]["id"].toString());
    storage.write(key: "loggedIn", value: "true");
    await fetchMenuData();
    setState(() {
      loggedIn = true;
    });
  }

  void payconiq(int index) async {
    var service = RestopolisApi();
    var response = await service.getPayconiqLink(accountId: account["objects"][0]["id"].toString(), value: index);
    if(response["code"] != 0) {
      return;
    }
    launchUrl(
      Uri.parse(response["objects"]["transactionUrl"]),
      mode: LaunchMode.externalApplication,
    );
  }
}