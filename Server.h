#pragma once
//Thread Libraries
#include <thread>
#include <condition_variable>
#include <mutex>
#include "Thread_Safe_Queue.h"
//Logging Libraries
#include <chrono>
#include <iostream>
#include <boost/program_options.hpp>
#include "cppkafka/producer.h"
#include "cppkafka/configuration.h"

//Internet Libraries
#include <boost/asio.hpp>

//Other Libraries
#include <string>
#include <vector>
#include <iomanip>
#include <cstdlib>
#include <stdexcept>

using std::string;
using cppkafka::Producer;
using cppkafka::Configuration;
using cppkafka::Topic;
using cppkafka::MessageBuilder;
using namespace boost::asio;
using ip::tcp;
using std::cout;
using std::endl;



namespace server
{
	class Server
	{
	public:
		Server(string broker_ip) : config{ { { "metadata.broker.list", "broker_ip" } } }, producer(config), acceptor_(io_service, tcp::endpoint(tcp::v4(), 6789)), socket_(io_service)
		{
			acceptor_.accept(socket_);

		}
	private:
		void compress(std::vector<std::vector<string>>& picture)
		{







			auto start = std::chrono::high_resolution_clock::now();


			// Your original dimensions
			size_t originalWidth = picture.size();
			size_t originalHeight = (picture.empty() ? 0 : picture[0].size());

			// Calculate the new dimensions (half the length of both dimensions)
			size_t newWidth = originalWidth / 2;
			size_t newHeight = originalHeight / 2;

			// Create a new vector with the new dimensions
			std::vector<std::vector<std::string>> newPicture(newWidth, std::vector<std::string>(newHeight));

			//Iterate through picture vector to downsample
			for (int column{ 0 }; column < picture[0].size(); column++)
			{
				for (int row{ 0 }; row < picture.size(); row++)
				{
					string& temptl = picture[row][column];
					string& temptr = picture[row][column + 1];
					string& tempbl = picture[row + 1][column];
					string& tempbr = picture[row + 1][column + 1];
					newPicture[row / 2][column / 2] = averageColors(temptl, temptr, tempbl, tempbr);
				}
			}
			auto end = std::chrono::high_resolution_clock::now();
			//std::string s = std::format("{0:%F %R %Z}", end);

			std::time_t currentTime = std::time(nullptr);

			// Create a buffer to store the formatted time
			char buffer[30]; // Adjust the size as needed

			// Format the time using strftime
			std::strftime(buffer, sizeof(buffer), "%F %R %Z", std::localtime(&currentTime));

			auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(end - start);
			//Call server send now

			//Call Kafka server send now
			std::string jsonString = "{"
				"\"time\": \"addm\", "
				"\"resolution\": \"" + std::to_string(picture[0].size()) + "x" + std::to_string(picture.size()) + "\", "
				"\"duration\": \"" + std::to_string(duration.count()) + " hours\""
				"}";
			MessageBuilder builder(jsonString);
			producer.produce(builder);

			producer.flush();

		}
		std::string averageColors(const std::string& color1, const std::string& color2, const std::string& color3, const std::string& color4) {
			// Convert hex strings to integers
			unsigned int tl = std::stoi(color1, nullptr, 16);
			unsigned int tr = std::stoi(color2, nullptr, 16);
			unsigned int bl = std::stoi(color3, nullptr, 16);
			unsigned int br = std::stoi(color4, nullptr, 16);

			// Extract color channels (R, G, B)
			unsigned int tlR = (tl >> 16) & 0xFF;
			unsigned int tlG = (tl >> 8) & 0xFF;
			unsigned int tlB = tl & 0xFF;

			unsigned int trR = (tr >> 16) & 0xFF;
			unsigned int trG = (tr >> 8) & 0xFF;
			unsigned int trB = tr & 0xFF;

			unsigned int blR = (bl >> 16) & 0xFF;
			unsigned int blG = (bl >> 8) & 0xFF;
			unsigned int blB = bl & 0xFF;

			unsigned int brR = (br >> 16) & 0xFF;
			unsigned int brG = (br >> 8) & 0xFF;
			unsigned int brB = br & 0xFF;

			// Average color channels
			unsigned int avgR = (tlR + trR + blR + brR) / 4;
			unsigned int avgG = (tlG + trG + blG + brG) / 4;
			unsigned int avgB = (tlB + trB + blB + brB) / 4;

			// Combine averaged channels and convert back to hex
			unsigned int avgColor = (avgR << 16) | (avgG << 8) | avgB;
			std::stringstream ss;
			ss << std::hex << std::setw(6) << std::setfill('0') << avgColor;

			return ss.str();
		}
		string read_(tcp::socket& socket) {
			boost::asio::streambuf buf;
			boost::asio::read_until(socket, buf, "\n");
			string data = boost::asio::buffer_cast<const char*>(buf.data());
			return data;
		}
		void send_(tcp::socket& socket, const string& message) {
			const string msg = message + "\n";
			boost::asio::write(socket, boost::asio::buffer(message));
		}









		// variables
		string brokers;
		string topic_name;
		int partition_value = -1;
		Producer producer;
		Configuration config;
		boost::asio::io_service io_service;
		tcp::acceptor acceptor_;
		tcp::socket socket_;
		std::thread connectionThread;
		
		


		thread_safe_queue::threadsafe_queue<std::string> pictureQueue;
	};
}