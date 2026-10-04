import 'dart:async';

/// The one browser flow the app may have open.
///
/// flutter_web_auth_2 keeps one pending result per callback scheme, and on the
/// web every pending popup listens for the same `auth.html` result, so two
/// flows in flight would trade callbacks. The slot records which flow owns the
/// browser: [claim] makes a flow the newest, and only the newest may spend a
/// callback. On the web a new click supersedes a pending flow (its popup may
/// have been closed without a word); on mobile the sheet is modal, so a start
/// while [isOpen] is a double tap and `SocialFlow` refuses it.
///
/// On the web a superseded flow may be handed the newest flow's callback:
/// flutter_web_auth_2 5.1.0 (`lib/src/web.dart:97-130`) has every pending flow
/// poll one localStorage key, and the first poller to see it removes it. The
/// stale flow passes such a callback on through [forward], and the newest flow
/// waits on [forwarded] beside its own browser.
///
/// Process-wide through [shared], because every driver builds its own flow and
/// they all share one browser.
class WebFlowSlot {
  /// The slot every `SocialFlow` uses unless a test hands it its own.
  static final WebFlowSlot shared = WebFlowSlot();

  _Flow? _newest;

  bool _open = false;

  /// True while the newest flow has not finished.
  bool get isOpen => _open;

  /// Makes a new flow the newest and returns its handle; every earlier flow is
  /// stale from here on.
  Object claim() {
    _open = true;

    return _newest = _Flow();
  }

  /// Whether [flow] is still the newest, so its completion may be spent.
  bool isCurrent(Object flow) => identical(flow, _newest);

  /// The callback a stale flow took on behalf of [flow], a handle from
  /// [claim]; never completes when no stale flow takes one.
  Future<Uri> forwarded(Object flow) => (flow as _Flow).callback.future;

  /// Hands [callback], taken by a stale flow, to the newest flow.
  ///
  /// Dropped when no flow is open or the newest already holds one, so a late
  /// stale result never reaches a flow that has finished.
  void forward(Uri callback) {
    final _Flow? newest = _newest;
    if (!_open || newest == null || newest.callback.isCompleted) return;

    newest.callback.complete(callback);
  }

  /// Ends [flow]; a stale flow finishing late leaves the newest one open.
  void release(Object flow) {
    if (isCurrent(flow)) _open = false;
  }
}

/// A claimed flow's handle, carrying the callback forwarded to it.
class _Flow {
  final Completer<Uri> callback = Completer<Uri>();
}
