# Description:
#   Manage Server Density alerts
#
# Commands:
#   /sd pause alert <alertID>
#   /sd resume alert <alertID>
#   /sd open alerts [<device/service ID>]?
#   /sd paused alerts?
#
# Configuration:
#   HUBOT_SD_API_TOKEN

class SDAlerts
	apiToken: process.env.HUBOT_SD_API_TOKEN
	baseURL: 'https://api.serverdensity.io'

	constructor: (@robot) -> @createCommands()

	createCommands: =>
		@robot.respond /^\/sd (resume|pause) (?:alert)?(?:\s)?([a-z0-9]{24})?$/i, @updateState
		@robot.respond /^\/sd open alerts(?:\s?)([a-z0-9]{24})\??$/i, @listOpen
		@robot.respond /^\/sd paused alerts\?$/i, @listPaused

	listPaused: (msg) =>
		msg.send "Fetching paused alerts..."

		filter =
			enabled: no

		params =
			token: @apiToken
			filter: JSON.stringify(filter)

		msg
			.http("#{@baseURL}/alerts/configs/")
			.headers
				'Accept': 'application/json'
				'Content-Type': 'application/json'

			.query(params)

			.get() (error, response, body) ->
				if error
					msg.send "HTTP Error: #{error}"

					return

				json = JSON.parse(body)

				if json.errors
					msg.send "API Error: #{json.errors.type}"
				else
					if json.length is 0
						msg.send "There are no paused alerts"
					else
						multiple = json.length isnt 1

						output = "\n\n${json.length} paused alert" + (if multiple then 's' else '')

						for alert, index in json
							output += "\n#{index + 1}) #{alert.fullField} #{alert.comparison} #{alert.value} for #{alert.subjectType} (#{alert.subjectId}) [_id: #{alert._id}]"

						output += "\n\n"

						msg.send output

	listOpen: (msg) =>
		subjectID = msg.match[1]

		msg.send "Fetching open alerts" + (if subjectID then " for #{subjectID}" else "") + "..."

		params =
			closed: no

		msg
			.http("#{@baseURL}/alerts/triggered/" + (subjectID or "") + "?token=#{@apiToken}")
			.headers
				'Accept': 'application/json'
				'content-type': 'application/json'

			.query(params)

			.get() (error, response, body) ->
				if error
					msg.send "HTTP Error: #{error}"

					return

				json = JSON.parse(body)

				if json.errors
					msg.send "API Error: #{json.errors.type}"
				else
					if json.length is 0
						msg.send 'No open alerts. Good. Good.'
					else
						output = "\n\n" + json.length + " open alert(s)\n"

						for alert, index in json
							output += "\n#{index + 1}) #{alert.config.fullField} #{alert.config.comparison} #{alert.config.value} for #{alert.config.subjectType} (#{alert.config.subjectId}) - [Config: #{alert.config._id}]"

						output += "\n\n"

						msg.send output

	updateState: (msg) =>
		command  = msg.match[1]
		configID = msg.match[2]

		unless configID
			msg.send "No config ID provided. *panics*"

			return

		msg.send command.charAt(0).toUpperCase() + command[1...command.length - 1] + 'ing alert...'

		data =
			enabled: (command is 'resume')

		msg
			.http("#{@baseURL}/alerts/configs/#{configID}?token=#{@apiToken}")
			.headers
				'Accept': 'application/json'
				'content-type': 'application/json'

			.put(JSON.stringify(data)) (error, response, body) ->
				if error
					msg.send "HTTP Error: #{error}"

					return

				response = JSON.parse(body)
				message  = if response.errors then "Error: #{response.errors.type}" else "#{command}d alert #{configID} (#{response.fullField} #{response.comparison} #{response.value})"

				msg.send message

module.exports = (robot) -> new SDAlerts(robot)
