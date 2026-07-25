import 'dart:async';

import 'package:flutter/material.dart';
import 'package:utils/utils.dart';

class ScrollingWidget extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final bool isScrolling;
  final Duration scrollSpeed;
  final Duration pauseDuration;

  const ScrollingWidget({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.isScrolling = true,
    this.scrollSpeed = const Duration(milliseconds: 50),
    this.pauseDuration = const Duration(seconds: 2),
  });

  @override
  State<ScrollingWidget> createState() => _ScrollingWidgetState();
}

class _ScrollingWidgetState extends State<ScrollingWidget> {
  late ScrollController _scrollController;
  Timer? _scrollTimer;
  bool _isForwardDirection = true;
  final GlobalKey _contentKey = GlobalKey();
  bool _isCurrentlyScrolling = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();

    // 초기 렌더링 후 스크롤 필요 여부 확인
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkNeedsScrolling();
    });
  }

  @override
  void didUpdateWidget(ScrollingWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // isScrolling 속성 변경 시 처리
    if (widget.isScrolling != oldWidget.isScrolling) {
      if (widget.isScrolling) {
        _checkNeedsScrolling();
      } else {
        _stopScrolling();
      }
    }
  }

  @override
  void dispose() {
    _stopScrolling();
    _scrollController.dispose();
    super.dispose();
  }

  void _checkNeedsScrolling() {
    if (!mounted || !widget.isScrolling) return;

    // 컨텐츠 크기가 화면 크기보다 큰지 확인
    final RenderBox? contentBox = _contentKey.currentContext?.findRenderObject() as RenderBox?;
    final containerWidth = context.size?.width ?? 0;

    if (contentBox == null) {
      // 렌더링 완료 후 다시 시도
      Future.delayed(const Duration(milliseconds: 100), _checkNeedsScrolling);
      return;
    }

    final contentWidth = contentBox.size.width;

    // 스크롤이 필요한 경우만 스크롤 시작
    if (contentWidth > containerWidth) {
      _startScrollingSequence();
    }
  }

  void _stopScrolling() {
    _scrollTimer?.cancel();
    _scrollTimer = null;
    _isCurrentlyScrolling = false;

    // 애니메이션이 진행 중이라면 중단
    if (_scrollController.hasClients && _scrollController.position.isScrollingNotifier.value) {
      _scrollController.jumpTo(_scrollController.offset);
    }
  }

  void _startScrollingSequence() {
    if (_isCurrentlyScrolling || !mounted || !widget.isScrolling) return;

    // 기존 타이머 정리
    _stopScrolling();

    if (!_scrollController.hasClients) {
      // 컨트롤러가 준비될 때까지 대기
      Future.delayed(const Duration(milliseconds: 100), _startScrollingSequence);
      return;
    }

    final scrollExtent = _scrollController.position.maxScrollExtent;

    // 스크롤이 필요없는 경우
    if (scrollExtent <= 5) return;

    _isCurrentlyScrolling = true;

    // 현재 방향에 따라 시작 또는 종료 지점에서 일시 정지
    if (_isForwardDirection && _scrollController.offset <= 5) {
      // 시작 지점에서 pauseDuration만큼 대기 후 정방향 스크롤 시작
      Future.delayed(widget.pauseDuration, () {
        if (mounted && widget.isScrolling) {
          _scrollToEnd();
        }
      });
    } else if (!_isForwardDirection && _scrollController.offset >= (scrollExtent - 5)) {
      // 종료 지점에서 pauseDuration만큼 대기 후 역방향 스크롤 시작
      Future.delayed(widget.pauseDuration, () {
        if (mounted && widget.isScrolling) {
          _scrollToStart();
        }
      });
    } else {
      // 중간 지점이라면 현재 방향에 맞게 스크롤 계속
      if (_isForwardDirection) {
        _scrollToEnd();
      } else {
        _scrollToStart();
      }
    }
  }

  void _scrollToEnd() {
    if (!mounted || !widget.isScrolling || !_scrollController.hasClients) {
      _isCurrentlyScrolling = false;
      return;
    }

    final scrollExtent = _scrollController.position.maxScrollExtent;
    // 스크롤 속도는 콘텐츠 길이에 비례하도록 계산
    final scrollDuration = Duration(milliseconds: (scrollExtent * 15).toInt());

    _scrollController
        .animateTo(
      scrollExtent,
      duration: scrollDuration,
      curve: Curves.linear,
    )
        .then((_) {
      _isCurrentlyScrolling = false;
      _isForwardDirection = false;

      // 종료 지점에 도달 후 다음 스크롤 시퀀스 시작
      if (mounted && widget.isScrolling) {
        _startScrollingSequence();
      }
    }).catchError((error) {
      logger.d('스크롤 오류: $error');
      _isCurrentlyScrolling = false;

      // 오류 발생 시 일정 시간 후 재시도
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && widget.isScrolling) {
          _startScrollingSequence();
        }
      });
    });
  }

  void _scrollToStart() {
    if (!mounted || !widget.isScrolling || !_scrollController.hasClients) {
      _isCurrentlyScrolling = false;
      return;
    }

    final scrollExtent = _scrollController.position.maxScrollExtent;
    // 스크롤 속도는 콘텐츠 길이에 비례하도록 계산
    final scrollDuration = Duration(milliseconds: (scrollExtent * 15).toInt());

    _scrollController
        .animateTo(
      0,
      duration: scrollDuration,
      curve: Curves.linear,
    )
        .then((_) {
      _isCurrentlyScrolling = false;
      _isForwardDirection = true;

      // 시작 지점에 도달 후 다음 스크롤 시퀀스 시작
      if (mounted && widget.isScrolling) {
        _startScrollingSequence();
      }
    }).catchError((error) {
      logger.d('스크롤 오류: $error');
      _isCurrentlyScrolling = false;

      // 오류 발생 시 일정 시간 후 재시도
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && widget.isScrolling) {
          _startScrollingSequence();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      // 레이아웃 변경 시 스크롤 필요 여부 재확인
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkNeedsScrolling();
      });

      return SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        child: Container(
          key: _contentKey,
          padding: widget.padding,
          child: widget.child,
        ),
      );
    });
  }
}
