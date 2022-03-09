#include "Modal2WaySplit.h"
#include <suh.h>

#define BOTTOM_LEFT Point(minX, minY)

#define TOP_LEFT Point(minX, maxY)

#define BOTTOM_RIGHT Point(maxX, minY)

#define TOP_RIGHT Point(maxX, maxY)

namespace EPP {
    bool Modal2WaySplit::appendForPolygonPart1(
            std::vector<EPP::Point> &points,
            const int minX_offset, const int minY_offset,
            const int maxX_offset, const int maxY_offset) noexcept {
        const Side firstSide = getSide(points[0]),
            lastSide = getSide(points[points.size() - 1]);
        if (firstSide==Side::NONE || lastSide==Side::NONE){
            return false;
        }
        int minX = 0 + minX_offset, minY = 0 + minY_offset,
                maxX = EPP::N + maxX_offset, maxY = EPP::N + maxY_offset;
        updatePoint(points, 0, minX, minY, maxX, maxY);
        updatePoint(points, points.size() - 1, minX, minY, maxX, maxY);
        if (firstSide == lastSide) {

        } else if ((firstSide == Side::LEFT && lastSide == Side::BOTTOM)
                   || (firstSide == Side::BOTTOM && lastSide == Side::LEFT)) {
            points.push_back(BOTTOM_LEFT); // bottom left corner
        } else if ((firstSide == Side::LEFT && lastSide == Side::TOP)
                   || (firstSide == Side::TOP && lastSide == Side::LEFT)) {
            points.push_back(TOP_LEFT);// top left corner
        } else if ((firstSide == Side::BOTTOM && lastSide == Side::TOP)) {
            points.push_back(TOP_LEFT); // top left corner
            points.push_back(BOTTOM_LEFT); // bottom left corner
        } else if ((firstSide == Side::TOP && lastSide == Side::BOTTOM)) {
            points.push_back(BOTTOM_LEFT);// bottom left corner
            points.push_back(TOP_LEFT); // top left corner
        } else if ((firstSide == Side::BOTTOM && lastSide == Side::RIGHT)
                   || (firstSide == Side::RIGHT && lastSide == Side::BOTTOM)) {
            points.push_back(BOTTOM_RIGHT); // bottom right corner
        } else if (firstSide == Side::LEFT && lastSide == Side::RIGHT) {
            points.push_back(TOP_RIGHT); // top right corner
            points.push_back(TOP_LEFT); // top left corner
        } else if (firstSide == Side::RIGHT && lastSide == Side::LEFT) {
            points.push_back(TOP_LEFT); // top left corner
            points.push_back(TOP_RIGHT); // top right corner
        } else /*if( (firstSide==Side::TOP && lastSide==Side::RIGHT)
                   || (firstSide==Side::RIGHT && lastSide==Side::TOP))*/ {
            points.push_back(TOP_RIGHT); // top right corner
        }
        points.push_back(points[0]);
        return true;
    }

    bool Modal2WaySplit::appendForPolygonPart2(
            std::vector<EPP::Point> &points,
            const int minX_offset, const int minY_offset,
            const int maxX_offset, const int maxY_offset) noexcept {
        // part 1 vs part 2
        // one 0 corner condition is four 4 corner conditions
        // four 1 corner conditions are eight 3 corner conditions
        const Point first = points[0], last = points[points.size() - 1];
        const Side firstSide = getSide(first), lastSide = getSide(last);
        if (firstSide==Side::NONE || lastSide==Side::NONE){
            return false;
        }
        int minX = 0 + minX_offset, minY = 0 + minY_offset,
                maxX = EPP::N + maxX_offset, maxY = EPP::N + maxY_offset;
        updatePoint(points, 0, minX, minY, maxX, maxY);
        updatePoint(points, points.size() - 1, minX, minY, maxX, maxY);
        if (firstSide == lastSide) { //  the tests below are ok with  state of first and last before updatePoint()
            // part 1's one 9 corner condition is four 4 corner conditions
            if (firstSide == Side::LEFT){
                if (first.j < last.j){ //last  point is higher on left side
                    points.push_back(TOP_LEFT);
                    points.push_back(TOP_RIGHT);
                    points.push_back(BOTTOM_RIGHT);
                    points.push_back(BOTTOM_LEFT);
                } else { // last point is lower on left side
                    points.push_back(BOTTOM_LEFT);
                    points.push_back(BOTTOM_RIGHT);
                    points.push_back(TOP_RIGHT);
                    points.push_back(TOP_LEFT);
                }
            } else if (firstSide == Side::TOP )  {
                if (first.i < last.i){ //last point is on right of top side
                    points.push_back(TOP_RIGHT);
                    points.push_back(BOTTOM_RIGHT);
                    points.push_back(BOTTOM_LEFT);
                    points.push_back(TOP_LEFT);

                } else { // last point is  on left of top side
                    points.push_back(TOP_LEFT);
                    points.push_back(BOTTOM_LEFT);
                    points.push_back(BOTTOM_RIGHT);
                    points.push_back(TOP_RIGHT);
                }
            } else if (firstSide == Side::BOTTOM )  {
                if (first.i < last.i){ //last point is on right of bottom side
                    points.push_back(BOTTOM_RIGHT);
                    points.push_back(TOP_RIGHT);
                    points.push_back(TOP_LEFT);
                    points.push_back(BOTTOM_LEFT);
                } else { // last point is  on left of bottom side
                    points.push_back(BOTTOM_LEFT);
                    points.push_back(TOP_LEFT);
                    points.push_back(TOP_RIGHT);
                    points.push_back(BOTTOM_RIGHT);
                }
            } else { //SIDE::RIGHT
                if (first.j < last.j){ // last point is higher on right side
                    points.push_back(TOP_RIGHT);
                    points.push_back(TOP_LEFT);
                    points.push_back(BOTTOM_LEFT);
                    points.push_back(BOTTOM_RIGHT);
                } else { // last point is lower on right side
                    points.push_back(BOTTOM_RIGHT);
                    points.push_back(BOTTOM_LEFT);
                    points.push_back(TOP_LEFT);
                    points.push_back(TOP_RIGHT);
                }
            }
        } else if (firstSide == Side::LEFT && lastSide == Side::BOTTOM) {
            points.push_back(BOTTOM_RIGHT);
            points.push_back(TOP_RIGHT);
            points.push_back(TOP_LEFT);
        } else if (firstSide == Side::BOTTOM && lastSide == Side::LEFT) {
            points.push_back(TOP_LEFT);
            points.push_back(TOP_RIGHT);
            points.push_back(BOTTOM_RIGHT);
        } else if (firstSide == Side::LEFT && lastSide == Side::TOP) {
            points.push_back(TOP_RIGHT);
            points.push_back(BOTTOM_RIGHT);
            points.push_back(BOTTOM_LEFT);
        } else if (firstSide == Side::TOP && lastSide == Side::LEFT) {
            points.push_back(BOTTOM_LEFT);
            points.push_back(BOTTOM_RIGHT);
            points.push_back(TOP_RIGHT);
        } else if (firstSide == Side::BOTTOM && lastSide == Side::TOP) {
            points.push_back(TOP_RIGHT); // top left corner
            points.push_back(BOTTOM_RIGHT); // bottom left corner
        } else if (firstSide == Side::TOP && lastSide == Side::BOTTOM) {
            points.push_back(BOTTOM_RIGHT);// bottom left corner
            points.push_back(TOP_RIGHT); // top left corner
        } else if (firstSide == Side::BOTTOM && lastSide == Side::RIGHT) {
            points.push_back(TOP_RIGHT);
            points.push_back(TOP_LEFT);
            points.push_back(BOTTOM_LEFT);
        } else if (firstSide == Side::RIGHT && lastSide == Side::BOTTOM) {
            points.push_back(BOTTOM_LEFT);
            points.push_back(TOP_LEFT);
            points.push_back(TOP_RIGHT);
        } else if (firstSide == Side::LEFT && lastSide == Side::RIGHT) {
            points.push_back(BOTTOM_RIGHT); // top right corner
            points.push_back(BOTTOM_LEFT); // top left corner
        } else if (firstSide == Side::RIGHT && lastSide == Side::LEFT) {
            points.push_back(BOTTOM_LEFT); // top left corner
            points.push_back(BOTTOM_RIGHT); // top right corner
        }
        // part 1's 1 corner becomes 3
        else if (firstSide==Side::TOP && lastSide==Side::RIGHT) {
            points.push_back(BOTTOM_RIGHT);
            points.push_back(BOTTOM_LEFT);
            points.push_back(TOP_LEFT);
        } else if (firstSide==Side::RIGHT && lastSide==Side::TOP) {
            points.push_back(TOP_LEFT);
            points.push_back(BOTTOM_LEFT);
            points.push_back(BOTTOM_RIGHT);
        }
        points.push_back(points[0]); // may differ from first if updatePoint() changed
        return true;
    }

}
