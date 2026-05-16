## Emails — phone "EMAIL" app data. Two groups:
##   STARTING — already in the inbox at game start
##   DRIP     — arrive over time via StocksState/Quest events. The runtime
##              state (which drip emails have landed yet) lives in PhoneState.
class_name Emails
extends Object

const STARTING := [
	{ "id": "willard_desk", "from_email": "willard@novacorp.com", "from": "Willard",
	  "subject": "Re: Your Desk", "time": "3 days ago",
	  "body": "Hey Ghost, cleaned out your desk. Found some crusty ramen. Gross.\n\n— Willard" },
	{ "id": "willard_ai", "from_email": "willard@novacorp.com", "from": "Willard",
	  "subject": "FYI", "time": "2 days ago",
	  "body": "Just wanted you to know they replaced you with an AI. It's already better. lol" },
	{ "id": "willard_fired", "from_email": "willard@novacorp.com", "from": "Willard",
	  "subject": "Meeting Notes", "time": "1 day ago",
	  "body": "Oh wait, you're fired. Never mind. 😂" },
	{ "id": "willard_worst", "from_email": "willard@novacorp.com", "from": "Willard",
	  "subject": "Seriously though", "time": "6 hrs ago",
	  "body": "You were always the worst coder on the team. Just saying." },
	{ "id": "hr_exit", "from_email": "hr@novacorp.com", "from": "NovaCorp HR",
	  "subject": "Exit Interview Reminder", "time": "4 days ago",
	  "body": "Dear former employee,\n\nPlease complete your exit interview at your earliest... oh wait." },
	{ "id": "hr_benefits", "from_email": "hr@novacorp.com", "from": "NovaCorp HR",
	  "subject": "Benefits Termination", "time": "2 days ago",
	  "body": "Your health insurance expires in 30 days. Good luck out there!\n\nRegards,\nHuman Resources" },
	{ "id": "novacorp_q3", "from_email": "newsletter@novacorp.com", "from": "NovaCorp Newsletter",
	  "subject": "NovaCorp Q3 Earnings", "time": "5 days ago",
	  "body": "Record profits! Thanks to everyone (except former employees).\n\nNovaCorp — Building Tomorrow, Without You™" },
	{ "id": "novacorp_picnic", "from_email": "newsletter@novacorp.com", "from": "NovaCorp Newsletter",
	  "subject": "Company Picnic", "time": "1 day ago",
	  "body": "You're not invited but it's going to be amazing.\n\nP.S. We hired a DJ. His name is also Ghost. He's better than you." },
]

# DRIP emails arrive on a timer (or quest event). PhoneState picks the next
# in order via drip_index and timer.
const DRIP := [
	{ "id": "drip_ai_promo", "from": "Willard", "from_email": "willard@novacorp.com",
	  "subject": "Update",
	  "body": "The AI that replaced you just got a promotion. Thought you should know." },
	{ "id": "drip_final_paycheck", "from": "NovaCorp HR", "from_email": "hr@novacorp.com",
	  "subject": "Final Paycheck",
	  "body": "After deductions for the ramen incident, you owe us $4.50." },
	{ "id": "drip_miss_you", "from": "Willard", "from_email": "willard@novacorp.com",
	  "subject": "Miss you (not)",
	  "body": "Actually the office is way better without you. Sorry not sorry." },
	{ "id": "drip_employee_month", "from": "NovaCorp Newsletter", "from_email": "newsletter@novacorp.com",
	  "subject": "Employee of the Month",
	  "body": "Congratulations to the AI that replaced Ghost! Third month in a row!" },
	{ "id": "drip_your_code", "from": "Willard", "from_email": "willard@novacorp.com",
	  "subject": "Your Code",
	  "body": "Found a bug in your old code today. It was the whole thing. The whole thing was a bug." },
	{ "id": "drip_reference", "from": "NovaCorp HR", "from_email": "hr@novacorp.com",
	  "subject": "Reference Request",
	  "body": "Someone called asking for a reference. We laughed. They laughed. Nobody got hired." },
	{ "id": "drip_meditation_pod", "from": "NovaCorp Newsletter", "from_email": "newsletter@novacorp.com",
	  "subject": "New Office Renovations",
	  "body": "Your old desk is now a meditation pod. It brings people more peace than you ever did." },
	{ "id": "drip_lunch", "from": "Willard", "from_email": "willard@novacorp.com",
	  "subject": "Lunch",
	  "body": "We went to that place you liked. It was mid. Like your code." },
]

## Inbox = starting emails + however many drip emails have arrived by now.
static func inbox(drip_arrived: int) -> Array:
	var out: Array = STARTING.duplicate()
	for i in min(drip_arrived, DRIP.size()):
		out.append(DRIP[i])
	return out
