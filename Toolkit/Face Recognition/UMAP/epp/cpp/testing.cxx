#include <iostream>
#include <fstream>
#include <sstream>
#include <thread>
#include "Modal2WaySplit.h"


int main(int argc, char *argv[]) {
    if (argc < 4) {
        std::cout << "Usage: " << argv[0] << " <csv-file> <rows> <columns> <threads default=#cpus>\n";
        return 1;
    }
    //EPP::testMexPolygon();
    long cost = 0;
    int measurements = std::stoi(argv[3]);
    long events = std::stoi(argv[2]);
    int threads = std::thread::hardware_concurrency();
    if (argc > 4)
        threads = std::stoi(argv[4]);
    // int threads = 1;

    // get some data from somewhere? CSV?
    float *data = new float[measurements * events]; //released when main exits
    std::ifstream datafile(argv[1], std::ios::in);
    if (!datafile.good()) {
        std::cout << "Cannot open file " << argv[1] << std::endl;
        return 1;
    }
    std::string line;
    std::string value;
    std::getline(datafile, line); // skip over header
    long i = 0;
    std::string lastLine;
    for (; i < events; i++) {
        if (i == events - 1) {
            lastLine += "Row #" + std::to_string(i) + ": ";
        }
        std::getline(datafile, line);
        std::stringstream sstr(line, std::ios::in);
        for (int j = 0; j < measurements; j++) {
            std::getline(sstr, value, ',');
            data[i + events * j] = std::stof(value); // MATLAB column wise expected
            if (i == events - 1) {
                lastLine += value + ", ";
            }
        }
    }
    datafile.close();
    std::cout << lastLine << std::endl;
    //EPP::testMex(data, events, measurements, 0, 1, .26, .3, "kld");
    EPP::testMex(data, events, measurements, 0, 1);
    EPP::testMex(data, events, measurements, 0, 6);

   // EPP::testMex(data, events, measurements);
//    EPP::Modal2WaySplit split(data, events, measurements, threads);
//    double *sptx = new double[split.size() * 2];
//    split.copyPoints(sptx, true, true);
//    split.print();
    std::cout << std::endl;
}