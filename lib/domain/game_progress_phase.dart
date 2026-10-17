/// Where in a 5-question set the child (or the controller) currently
/// sits. Used by [GameProgress] to allow an app restart to resume
/// *exactly* where the play session was interrupted (Issue #22).
///
/// Note: this is independent of [GameState] because some phases
/// (`setCompleted`, `resting`) carry no active round, so storing the
/// phase itself is the cleanest way to distinguish "I was about to
/// answer question 3" from "I was on the review screen".
enum SessionPhase {
  /// The child is choosing among the options of the next round.
  solving,

  /// The child just answered correctly; the FX is playing (Game
  /// state `Solved`). Re-entering the app replays the FX and lets
  /// the user advance normally via `onEffectFinished`.
  solved,

  /// All five questions in the current set have been answered
  /// correctly; the review area is shown (`SetCompletedState`).
  setCompleted,

  /// The child took a Rest on the review area, so the resting
  /// screen is shown (`RestingState`).
  resting,
}
