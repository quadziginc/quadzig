import mixPanelTrack from 'src/mixpanel_init';

if (window.mixpanel) {
  mixPanelTrack("visited_subscriptions_page", {})
}