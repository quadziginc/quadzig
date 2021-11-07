export default function mixPanelTrack(eventName, eventProps) {
  if (window.mixpanel) {
    if (Object.keys(eventProps).length === 0) {
      window.mixpanel.track(eventName);
    } else {
      window.mixpanel.track(eventName, eventProps);
    }
  }
}