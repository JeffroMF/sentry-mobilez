import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../redux/state/app_state.dart';
import '../../screens/empty/empty_screen.dart';
import '../../types/session_status.dart';
import '../../utils/sentry_colors.dart';
import 'health_card.dart';
import 'health_divider.dart';
import 'health_screen_view_model.dart';
import 'sessions_chart_row.dart';

class HealthScreen extends StatefulWidget {
  const HealthScreen({Key? key}) : super(key: key);

  @override
  _HealthScreenState createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen>
    with WidgetsBindingObserver {
  int? _index;
  bool _ratingPresented = false;

  final _refreshKey = GlobalKey<RefreshIndicatorState>();
  final InAppReview inAppReview = InAppReview.instance;

  PageController? _pageController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance?.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance?.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, HealthScreenViewModel>(
      builder: (_, viewModel) => _content(viewModel),
      converter: (store) => HealthScreenViewModel.fromStore(store),
      onInitialBuild: (viewModel) => viewModel.fetchProjects(),
    );
  }

  Widget _content(HealthScreenViewModel viewModel) {
    if (viewModel.showLoadingScreen) {
      return Center(
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
            CircularProgressIndicator(value: viewModel.loadingProgress),
            Container(
                padding: EdgeInsets.symmetric(vertical: 16, horizontal: 22),
                child: Text(viewModel.loadingText ?? 'Loading ...'))
          ]));
    } else if (viewModel.showErrorScreen) {
      if (viewModel.showErrorNoConnectionScreen) {
        return EmptyScreen(
            title: 'No connection',
            text: 'Please check your connection and try again.',
            button: 'Retry',
            action: () {
              viewModel.fetchProjects();
              _reloadSessionData(viewModel, _index ?? 0);
            });
      } else {
        return EmptyScreen(
            title: 'Ooops',
            text: 'Something went wrong. Please try again.',
            button: 'Retry',
            action: () {
              viewModel.fetchProjects();
              _reloadSessionData(viewModel, _index ?? 0);
            });
      }
    } else if (viewModel.showProjectEmptyScreen) {
      return EmptyScreen(
        title: 'Have you set up\nRelease Health?',
        text:
            'We have identified that none of your projects are configured to support Release Health. Head over to our the documentation to learn more.',
        button: 'Open Documentation',
        action: () async {
          const url = 'https://docs.sentry.io/product/releases/health/setup/';
          if (await canLaunch(url)) {
            await launch(url, forceSafariVC: false);
          } else {
            throw 'Could not launch $url';
          }
        },
        secondaryButton: 'Refresh Projects',
        secondaryAction: () {
          viewModel.fetchProjects();
          _reloadSessionData(viewModel, _index ?? 0);
        },
      );
    } else {
      WidgetsBinding.instance?.addPostFrameCallback((Duration duration) {
        if (viewModel.showLoadingScreen) {
          _refreshKey.currentState!.show();
        } else {
          _refreshKey.currentState!.deactivate();
        }
      });

      final updateIndex = (int index) {
        viewModel.fetchDataForProject(index);
        _index = index;
      };

      if (_index == null || _index! >= viewModel.projects.length) {
        updateIndex(0);
      }

      final index = _index ?? 0;

      if (viewModel.shouldPresentRating() && !_ratingPresented) {
        _ratingPresented = true;
        inAppReview.requestReview();
        viewModel.didPresentRating();
      }

      return RefreshIndicator(
        key: _refreshKey,
        backgroundColor: Colors.white,
        color: Color(0xff81B4FE),
        child: LayoutBuilder(builder:
            (BuildContext context, BoxConstraints viewportConstraints) {
          _pageController = PageController(
              viewportFraction: (MediaQuery.of(context).size.width - 32) /
                  MediaQuery.of(context).size.width);

          return ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: viewportConstraints.maxHeight,
            ),
            child: SingleChildScrollView(
              physics: AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.only(left: 22, right: 22),
                    child: HealthDivider(
                      onSeeAll: () {},
                      title: 'in the last 24 hours',
                    ),
                  ),
                  SizedBox(
                      height: 208,
                      child: PageView.builder(
                        itemCount: viewModel.projects.length,
                        controller: _pageController,
                        onPageChanged: (int index) {
                          viewModel.didInteract();
                          setState(() {
                            updateIndex(index);
                            // Fetch next projects at end
                            if (index == viewModel.projects.length - 1) {
                              viewModel.fetchProjects();
                            }
                          });
                        },
                        itemBuilder: (context, index) {
                          return viewModel.projectCard(index);
                        },
                      )),
                  Container(
                    padding: EdgeInsets.only(top: 8, left: 22, right: 22),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              HealthCard(
                                title: 'Crash Free Sessions',
                                viewModel: viewModel
                                    .crashFreeSessionsForProject(index),
                              ),
                              SizedBox(width: 8),
                              HealthCard(
                                title: 'Crash Free Users',
                                viewModel:
                                    viewModel.crashFreeUsersForProject(index),
                              ),
                            ],
                          ),
                        ),
                        SessionsChartRow(
                          title: 'Healthy',
                          color: SentryColors.buttercup,
                          sessionState: viewModel.sessionState(
                              index, SessionStatus.healthy),
                          flipDeltaColors: true,
                        ),
                        SessionsChartRow(
                          title: 'Errored',
                          color: SentryColors.eastBay,
                          sessionState: viewModel.sessionState(
                              index, SessionStatus.errored),
                        ),
                        if (viewModel.showAbnormalSessions(index))
                          SessionsChartRow(
                            title: 'Abnormal',
                            color: SentryColors.tapestry,
                            sessionState: viewModel.sessionState(
                                index, SessionStatus.abnormal),
                          ),
                        SessionsChartRow(
                          title: 'Crashed',
                          color: SentryColors.burntSienna,
                          sessionState: viewModel.sessionState(
                              index, SessionStatus.crashed),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        onRefresh: () => Future.delayed(Duration(microseconds: 100), () {
          viewModel.didInteract();
          viewModel.reloadProjects();
          _reloadSessionData(viewModel, _index ?? 0);
        }),
      );
    }
  }

  // Reload session data for previous, current and next index.
  void _reloadSessionData(HealthScreenViewModel viewModel, int currentIndex) {
    viewModel.fetchDataForProject(currentIndex - 1);
    viewModel.fetchDataForProject(currentIndex);
    viewModel.fetchDataForProject(currentIndex + 1);
  }

  // WidgetsBindingObserver

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    final store = StoreProvider.of<AppState>(context);
    final orgsAndProjectsError = store.state.globalState.orgsAndProjectsError;

    if (state == AppLifecycleState.resumed && orgsAndProjectsError != null) {
      final viewModel = HealthScreenViewModel.fromStore(store);
      viewModel.reloadProjects();
      viewModel.fetchDataForProject(_index ?? 0);
    }
  }
}
