import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../redux/state/app_state.dart';
import '../../screens/empty/empty_screen.dart';
import '../../utils/sentry_colors.dart';
import '../../utils/sentry_icons.dart';
import 'health_screen_view_model.dart';
import 'project_card.dart';
import 'sessions_chart_row.dart';

class HealthScreen extends StatefulWidget {
  const HealthScreen({Key key}) : super(key: key);

  @override
  _HealthScreenState createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  int _index;

  final _refreshKey = GlobalKey<RefreshIndicatorState>();

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, HealthScreenViewModel>(
      builder: (_, viewModel) => _content(viewModel),
      converter: (store) => HealthScreenViewModel.fromStore(store),
    );
  }

  Widget _content(HealthScreenViewModel viewModel) {
    viewModel.fetchProjectsIfNeeded();

    if (viewModel.showProjectEmptyScreen || viewModel.showReleaseEmptyScreen) {
      _index = 0;

      String text = '';
      if (viewModel.showProjectEmptyScreen) {
        text = 'You need at least one project to use this view.';
      }
      if (viewModel.showReleaseEmptyScreen) {
        text = 'You need at least one release in you projects to use this view.';
      }
      return EmptyScreen(
        title: 'Remain Calm',
        text: text,
        button: 'Visit sentry.io',
        action: () async {
          const url = 'https://sentry.io';
          if (await canLaunch(url)) {
            await launch(url);
          }
        }
      );
    } else if (viewModel.showLoadingScreen || viewModel.projects.isEmpty) {
      _index = 0;

      return Center(
        child: CircularProgressIndicator(),
      );
    } else {

      WidgetsBinding.instance.addPostFrameCallback( ( Duration duration ) {
        if (viewModel.showLoadingScreen) {
          _refreshKey.currentState.show();
        } else {
          _refreshKey.currentState.deactivate();
        }
      });

      final updateIndex = (int index) {
        viewModel.fetchLatestReleaseOrIssues(index);
        _index = index;
      };

      if (_index == null) {
        updateIndex(0);
      } else {
        updateIndex(_index);
      }

      return RefreshIndicator(
        key: _refreshKey,
        backgroundColor: Colors.white,
        color: Color(0xff81B4FE),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints viewportConstraints) {
            return ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: viewportConstraints.maxHeight,
              ),
              child: SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    SizedBox(
                        height: 200,
                        child: PageView.builder(
                          itemCount: viewModel.projects.length,
                          controller: PageController(viewportFraction: 0.9),
                          onPageChanged: (int index) => setState(() => updateIndex(index)),
                          itemBuilder: (context, index) {
                            final projectWitLatestRelease = viewModel.projects[index];
                            return ProjectCard(
                                projectWitLatestRelease.project,
                                projectWitLatestRelease.release,
                                viewModel.sessionStateForProject(projectWitLatestRelease.project)
                            );
                          },
                        )),
                    Container(
                      padding: EdgeInsets.only(top: 22, left: 22, right: 22),
                      child: Column(
                        children: [
                          HealthDivider(
                            onSeeAll: () {},
                            title: 'Charts',
                          ),
                          SessionsChartRow(
                            title: 'Issues',
                            sessionState: viewModel.handledAndCrashedSessionStateForProject(viewModel.projects[_index].project),
                          ),
                          SessionsChartRow(
                            title: 'Crashes',
                            sessionState: viewModel.crashedSessionStateForProject(viewModel.projects[_index].project),
                            parentPoints: viewModel.handledAndCrashedSessionStateForProject(viewModel.projects[_index].project)?.points,
                          ),
                          HealthDivider(
                            onSeeAll: () {},
                            title: 'Statistics',
                          ),
                          Row(
                            children: [
                              HealthCard(
                                  title: 'Crash Free Users',
                                  value: viewModel.projects[_index].release?.crashFreeUsers,
                                  change: 0.04
                              ), // TODO(denis): Use delta from api, https://github.com/getsentry/sentry-mobile/issues/11
                              HealthCard(
                                  title: 'Crash Free Sessions',
                                  value: viewModel.projects[_index].release?.crashFreeSessions,
                                  change: -0.01
                              ), // TODO(denis): Use delta from api, https://github.com/getsentry/sentry-mobile/issues/11
                            ],
                          )
                        ],
                      ),
                    ),
                    // Column(children: [
                    //   // WARNING Those line charts are just stacked one over the other, so the scaling between them is not in sync. Implement if we will keep this view.
                    //   Stack(
                    //     children: [
                    //       Container(
                    //         height: 120,
                    //         child: LineChart(
                    //             points: ReleaseHealthData.palceholderHealthy,
                    //             lineWidth: 1.0,
                    //             lineColor: Color(0xffffc227),
                    //             gradientStart: Color(0xffffc227),
                    //             gradientEnd: Color(0xe1ffc227)
                    //         ),
                    //       ),
                    //       Container(
                    //         height: 120,
                    //         child: LineChart(
                    //             points: ReleaseHealthData.placeholderError,
                    //             lineWidth: 1.0,
                    //             lineColor: Color(0xffef7061),
                    //             gradientStart: Color(0xffef7061),
                    //             gradientEnd: Color(0xe1ef7061)
                    //         ),
                    //       ),
                    //       Container(
                    //         height: 120,
                    //         child: LineChart(
                    //             points: ReleaseHealthData.placeholderAbnormal,
                    //             lineWidth: 1.0,
                    //             lineColor: Color(0xffa35488),
                    //             gradientStart: Color(0xffa35488),
                    //             gradientEnd: Color(0xe1a35488)
                    //         ),
                    //       ),
                    //       Container(
                    //         height: 120,
                    //         child: LineChart(
                    //             points: ReleaseHealthData.placeholderCrashes,
                    //             lineWidth: 1.0,
                    //             lineColor: Color(0xff444674),
                    //             gradientStart: Color(0xff444674),
                    //             gradientEnd: Color(0xe1444674)
                    //         ),
                    //       ),
                    //     ],
                    //   )
                    //
                    // ])
                  ],
                ),
              ),
            );
          }
        ),
        onRefresh: () => Future.delayed(
          Duration(microseconds: 100),
          () { viewModel.fetchProjects(); }
        ),
      );
    }
  }
}

class HealthDivider extends StatelessWidget {
  HealthDivider(
      {@required this.title,
      @required this.onSeeAll});

  final String title;
  final void Function() onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(top: 6.0, bottom: 22.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              color: SentryColors.mamba,
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
          // MaterialButton(
          //   minWidth: 0,
          //   padding: EdgeInsets.zero,
          //   onPressed: onSeeAll,
          //   child: Text(
          //     'See All',
          //     style: TextStyle(
          //       color: Color(0xFF81B4FE),
          //       fontWeight: FontWeight.w500,
          //       fontSize: 16,
          //     ),
          //   ),
          // )
        ],
      ),
    );
  }
}

class HealthCard extends StatelessWidget {
  HealthCard(
      {@required this.title, this.value, @required this.change});

  final String title;
  final double value;
  final double change;

  final warningThreshold = 99.5;
  final dangerThreshold = 98;
  final valueFormat = NumberFormat('###.##');

  Color getColor() {
    return value == null
        ? SentryColors.lavenderGray
        : value > warningThreshold
          ? SentryColors.shamrock
          : value > dangerThreshold ? SentryColors.lightningYellow : SentryColors.burntSienna;
  }

  Icon getIcon(Color color) {
    if (value == null) {
      return null;
    }
    return value > warningThreshold
        ? Icon(SentryIcons.status_ok, color: color, size: 20.0)
        : value > dangerThreshold
            ? Icon(SentryIcons.status_warning, color: color, size: 20.0)
            : Icon(SentryIcons.status_error, color: color, size: 20.0);
  }

  String getTrendSign() {
    return change > 0 ? '+' : '';
  }

  Icon getTrendIcon() {
    if (change == 0) {
      return null;
    }
    return change == 0
      ? Icon(SentryIcons.trend_same, color: SentryColors.lavenderGray, size: 8.0)
      :  change > 0
        ? Icon(SentryIcons.trend_up, color: SentryColors.shamrock, size: 8.0)
        : Icon(SentryIcons.trend_down, color: SentryColors.burntSienna, size: 8.0);
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
        child: Card(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(15))),
      elevation: 4,
      shadowColor: SentryColors.silverChalice.withAlpha((256 * 0.2).toInt()),
      margin: EdgeInsets.only(left: 7, right: 7, top: 0, bottom: 22),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 8, bottom: 8),
            child: CircleAvatar(
              radius: 24,
              backgroundColor: getColor().withAlpha(0x19),
              child: getIcon(getColor()),
            )
          ),
          Text(
            value != null ? valueFormat.format(value) + '%' : '--',
            style: TextStyle(
              color: getColor(),
              fontWeight: FontWeight.w500,
              fontSize: 17,
            ),
          ),
          Padding(
              padding: EdgeInsets.only(top: 5, bottom: 8),
              child: Text(
                title,
                style: TextStyle(
                  color: SentryColors.revolver,
                  fontSize: 14,
                ),
              )),
          Padding(
            padding: EdgeInsets.only(bottom: 8),
            child:
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Text(
                  //   change != null ? getTrendSign() + change.toString() + '%' : '--',
                  //   style: TextStyle(
                  //     color: SentryColors.mamba,
                  //     fontSize: 13,
                  //   ),
                  // ),
                  // Padding(
                  //   padding: EdgeInsets.only(left: 5),
                  //   child: getTrendIcon() ?? Spacer(),
                  // )
                ]
              )
          ),
        ],
      ),
    ));
  }
}