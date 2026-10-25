import sqlite3
import datetime
import telebot
from telebot import types

TOKEN = "8980553171:AAElLzmT-HnaZ_zo-LXykahE7e-WLE_-oqQ"
bot = telebot.TeleBot(TOKEN)

def init_db():
	conn = sqlite3.connect("bot_stats.db")
	cursor = conn.cursor()
	cursor.execute("""
		CREATE TABLE IF NOT EXISTS users (
			user_id INTEGER PRIMARY KEY,
			name TEXT,
			username TEXT,
			today_count INTEGER DEFAULT 0,
			week_count INTEGER DEFAULT 0,
			last_date TEXT,
			week_start_date TEXT
		)
	""")
	conn.commit()
	conn.close()

init_db()

@bot.message_handler(commands=['start'])
def cmd_start(message):
    bot.reply_to(message, "Привіт абриКОСик хєх!")

@bot.message_handler(commands=['join'])
def cmd_join(message):
	user_id = message.from_user.id
	name = message.from_user.first_name
	username = message.from_user.username
	today = str(datetime.datetime.now().date())
	
	conn = sqlite3.connect("bot_stats.db")
	cursor = conn.cursor()
	cursor.execute("""
    		INSERT INTO users (user_id, name, username, today_count, week_count, last_date, week_start_date)
    		VALUES (?, ?, ?, 0, 0, ?, ?)
    		ON CONFLICT(user_id) DO UPDATE SET name = excluded.name, username = excluded.username
	""", (user_id, name, username, today, today))
	conn.commit()
	conn.close()
    
	bot.reply_to(message, "✅ Ти успішно зареєстрова(ний/на/ні/не) у базі для заклику!")

@bot.message_handler(commands=['stats_day'])
def cmd_stats_day(message):
	conn = sqlite3.connect("bot_stats.db")
	cursor = conn.cursor()
	
	now = str(datetime.datetime.now().date())
	cursor.execute("SELECT name, username, today_count FROM users WHERE last_date = ? AND today_count > 0 ORDER BY today_count DESC", (now,))
	rows = cursor.fetchall()
	conn.close()
	
	if not rows:
	   bot.reply_to(message, "уу креветки пробивають дно")
	   return
    
	text = "📊 Активність чату (сьогодні):\n\n"
	for i, (name, username, count) in enumerate(rows, 1):
		display_name = name if name else (username if username else "без імені")
		text += f"{i}. {display_name} — {count} повідомлень\n"
    
	bot.send_message(message.chat.id, text)

@bot.message_handler(commands=['stats_week'])
def cmd_stats_week(message):
	conn = sqlite3.connect("bot_stats.db")
	cursor = conn.cursor()
	
	cursor.execute("SELECT name, username, week_count FROM users WHERE week_count > 0 ORDER BY week_count DESC")
	rows = cursor.fetchall()
	conn.close()
	
	if not rows:
	   bot.reply_to(message, "вже холодні")
	   return
    
	text = "📈 Активність чату (за тиждень):\n\n"
	for i, (name, username, count) in enumerate(rows, 1):
		display_name = name if name else (username if username else "без імені")
		text += f"{i}. {display_name} — {count} повідомлень\n"
    
	bot.send_message(message.chat.id, text)

@bot.message_handler(commands=['broadcast', 'ping'])
def cmd_broadcast_call(message):
	if message.chat.type not in ['group', 'supergroup']:
		bot.reply_to(message, "⚠️ Цю команду можна використовувати лише в чаті (групі)!")
		return
		
	conn = sqlite3.connect("bot_stats.db")
	cursor = conn.cursor()
	cursor.execute("SELECT name, username FROM users")
	users = cursor.fetchall()
	conn.close()
	
	if not users:
	   bot.reply_to(message, "⚠️ У базі ще немає зареєстрованих користувачів.")
	   return
	   
	mentions = []
	for (name, username) in users:
	   if username:
	   	mentions.append(f"@{username}")
	   else:
	   	display_name = name if name else "без імені"
	   	mentions.append(display_name)
	   
	call_text = "🔔 Заклик!\n\n" + ", ".join(mentions)
	bot.send_message(message.chat.id, call_text)
	
@bot.message_handler(func=lambda message: True)
def all_messages(message):
	user_id = message.from_user.id
	name = message.from_user.first_name
	username = message.from_user.username
	today_date = datetime.datetime.now().date()
	today_str = str(today_date)
	
	conn = sqlite3.connect("bot_stats.db")
	cursor = conn.cursor()
	
	cursor.execute("SELECT today_count, week_count, last_date, week_start_date FROM users WHERE user_id = ?", (user_id,))
	row = cursor.fetchone()
	
	if not row:
	       cursor.execute("""
	       	INSERT INTO users (user_id, name, username, today_count, week_count, last_date, week_start_date)
	       	VALUES (?, ?, ?, 1, 1, ?, ?)
	       """, (user_id, name, username, today_str, today_str))
	else:
	   today_count, week_count, last_date, week_start_date = row
	   
	   if last_date != today_str:
	       today_count = 0
	       last_date = today_str
	   
	   if week_start_date:
	       start_date_obj = datetime.datetime.strptime(week_start_date, "%Y-%m-%d").date()
	       if (today_date - start_date_obj).days >= 7:
	           week_count = 0
	           week_start_date = today_str
	       else:
	       	week_start_date = today_str
	       
	       today_count += 1
	       week_count += 1
	       
	       cursor.execute("""
	       	UPDATE users 
	       	SET today_count = ?, week_count = ?, last_date = ?, week_start_date = ?, name = ?, username = ? 
	       	WHERE user_id = ?
	       """, (today_count, week_count, last_date, week_start_date, name, username, user_id))
    
	conn.commit()
	conn.close()

if __name__ == "__main__":
	print("Бот ззапущено!")
	bot.infinity_polling()