extends RefCounted
## Reminders while fosh&fish is in the background (Settings -> Reminders): the crews filled the cooler, the
## daily reward is ready, the free spin is back. Web: the browser's own notifications (it asks once), shown
## only while the tab is hidden. Android needs a local-notification plugin (not in the project yet, see
## docs/PLAY_STORE.md). Desktop: none.


func supported() -> bool:
	return OS.has_feature("web")


## "granted" / "denied" / "default" (not asked yet); "" where there are no notifications
func permission() -> String:
	if not OS.has_feature("web"): return ""
	var p: Variant = JavaScriptBridge.eval("('Notification' in window) ? Notification.permission : ''", true)
	return String(p) if p != null else ""


## the browser asks the player (only the first time)
func ask() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("if ('Notification' in window && Notification.permission === 'default') Notification.requestPermission();", true)


## what to say, and when (seconds from now)
func reminders() -> Array:
	var out := []
	if VF.crews > 0:
		out.append({"id": "cooler", "secs": VF.offline_cap_secs(), "title": "Your crews filled the cooler!",
			"body": "%d crew%s fished for you all this time. Come and collect the catch." % [VF.crews, "" if VF.crews == 1 else "s"]})
	if VF.level >= VFData.DAILY_LEVEL:
		var d: float = VF.daily_ready_in()
		var day: int = VF.calendar_next()
		out.append({"id": "daily", "secs": d if d > 60.0 else 4.0 * 3600.0, "title": "Your daily reward is ready",
			"body": "Day %d of your calendar: %s." % [day, VFData.CALENDAR[day - 1].name]})
		if not VF.spin_free():
			out.append({"id": "spin", "secs": 86400.0 - fmod(Time.get_unix_time_from_system(), 86400.0) + 60.0,
				"title": "Free spin!", "body": "Your daily spin is back. The jackpot: 50 Pearls and a legendary chest."})
	return out


## the game went to the background: set them up (web: timers in the page, fired only while the tab is hidden)
func schedule() -> void:
	if not AudioManager.notify_on or not supported(): return
	var list := []
	for r in reminders():
		list.append({"tag": "fosh-" + String(r.id), "ms": int(float(r.secs) * 1000.0), "title": r.title, "body": r.body})
	JavaScriptBridge.eval("""(function (list) {
	(window.__fishNotes || []).forEach(clearTimeout);
	window.__fishNotes = [];
	if (!('Notification' in window) || Notification.permission !== 'granted') return;
	var icon = (document.querySelector("link[rel~='icon']") || {}).href;
	list.forEach(function (n) {
		window.__fishNotes.push(setTimeout(function () {
			if (document.hidden) new Notification(n.title, {body: n.body, tag: n.tag, icon: icon});
		}, n.ms));
	});
})(%s);""" % JSON.stringify(list), true)


## back in the game: nothing to remind about
func cancel() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("(window.__fishNotes || []).forEach(clearTimeout); window.__fishNotes = [];", true)
