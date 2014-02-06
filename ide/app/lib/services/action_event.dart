/**
 * Defines a received action event.
 */
class ActionEvent {
  // TODO(ericarnold): Extend Event?
  // TODO(ericarnold): This should be shared between ServiceIsolate and Service.
  String serviceId;
  String actionId;
  String callId;
  Map data;
  ActionEvent(this.serviceId, this.actionId, this.callId, this.data);
}
