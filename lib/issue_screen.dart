import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'text_theme_ext.dart';
import 'types/event.dart';

class IssueScreen extends StatefulWidget {
  const IssueScreen({Key key}) : super(key: key);

  @override
  _IssueState createState() => _IssueState();
}

Future<Event> fetchEvent() async {
  final response =
      await http.get('https://jennmueng.com/sentry_sample_event.json');

  if (response.statusCode == 200) {
    // If the server did return a 200 OK response,
    // then parse the JSON.
    final Map<String, dynamic> responseJson =
        json.decode(response.body) as Map<String, dynamic>;
    return Event.fromJson(responseJson);
  } else {
    // If the server did not return a 200 OK response,
    // then throw an exception.
    throw Exception('Failed to load Release');
  }
}

class _IssueState extends State<IssueScreen> {
  Future<Event> futureEvent = null;

  @override
  void initState() {
    super.initState();
    getSampleData();
  }

  void getSampleData() {
    setState(() {
      futureEvent = fetchEvent();
    });
  }

  Widget build(BuildContext context) {
    return FutureBuilder<Event>(
        future: futureEvent,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            final event = snapshot.data;

            return SingleChildScrollView(
                child: Container(
                    height: 1000,
                    padding: EdgeInsets.only(top: 20, left: 16, right: 16),
                    child: Column(
                      children: [
                        Container(
                            alignment: Alignment.topLeft,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(event.metadata.type,
                                    style:
                                        Theme.of(context).textTheme.headline1),
                                Text(event.culprit,
                                    style: TextStyle(
                                        color: Colors.black54,
                                        fontSize: Theme.of(context)
                                            .textTheme
                                            .headline2
                                            .fontSize)),
                                Container(
                                    margin: EdgeInsets.only(top: 12),
                                    child: Text(event.title,
                                        style: TextStyle(
                                            color: Colors.black,
                                            fontSize: Theme.of(context)
                                                .textTheme
                                                .headline4
                                                .fontSize)))
                              ],
                            )),
                        Tags(tags: event.tags)
                      ],
                    )));
          } else if (snapshot.hasError) {
            return Text('${snapshot.error}');
          }

          return Center(
            child: CircularProgressIndicator(),
          );
        });
  }
}

class Tags extends StatelessWidget {
  Tags({@required this.tags});
  final List<Tag> tags;

  Widget build(BuildContext context) {
    return Container(
        margin: EdgeInsets.only(top: 12),
        alignment: Alignment.topLeft,
        child: Column(
          children: <Widget>[
            Container(
                margin: EdgeInsets.only(bottom: 8),
                alignment: Alignment.topLeft,
                child:
                    Text('TAGS', style: Theme.of(context).textTheme.caption)),
            Wrap(
                spacing: 8.0, // gap between adjacent chips
                runSpacing: 8.0, // gap between lines,
                runAlignment: WrapAlignment.spaceBetween,
                direction: Axis.horizontal,
                crossAxisAlignment: WrapCrossAlignment.start,
                children: tags
                    .map((Tag tag) =>
                        TagCard(tagKey: tag.key, tagValue: tag.value))
                    .toList()),
          ],
        ));
  }
}

class TagCard extends StatelessWidget {
  TagCard({@required this.tagKey, @required this.tagValue});

  final String tagKey;
  final String tagValue;

  Widget build(BuildContext context) {
    return Container(
      height: 26,
      decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.all(Radius.circular(3)),
          border: Border.all(
            color: Color(0xffc6becf),
            width: 1,
          )),
      child: ClipRRect(
          borderRadius: BorderRadius.all(Radius.circular(3)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  height: 26,
                  alignment: Alignment.centerRight,
                  child: Text(tagKey),
                  decoration: const BoxDecoration(
                    border: Border(
                      right: BorderSide(width: 1.0, color: Color(0xffc6becf)),
                    ),
                    color: Color(0xfffaf9fb),
                  )),
              Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Text(tagValue,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.left,
                      style: TextStyle(
                          fontFamily:
                              Theme.of(context).textTheme.code.fontFamily,
                          color: Theme.of(context).primaryColorDark))),
            ],
          )),
    );
  }
}