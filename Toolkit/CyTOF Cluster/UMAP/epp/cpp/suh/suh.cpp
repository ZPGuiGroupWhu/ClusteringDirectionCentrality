//
// Created by Stephen Meehan on 5/18/21.
//
#include "suh.h"
#include <iomanip>
namespace suh {
    SUH_ID_FACTORY;

    std::set<int> debug_keys;
    int debug_key_cnt=0;
    bool debug_ctor_dtor = false;

    const std::string empty = "";

    std::string to_string(const double value, const int decimals, const bool separateThousands) noexcept{
        if (std::isnan(value)) {
            return "nan";
        }
        std::strstream ss;
        ss << std::fixed;
        if (floor(value) == value)
            ss << std::setprecision(0);
        else
            ss << std::setprecision(decimals);
        ss << value;
        const char *c = ss.str();
        int decIdx = strcspn(c, ".");
        if (decIdx > 3) { // simple C code to provide thousands separation
            const size_t sz = strlen(c);
            if (sz < 1250) {
                char buf[1252] = "fake info number";//should be big ENOUGH for any number right?
                char *to = buf;
                const char *end = c + sz, *dec = c + decIdx;
                for (; c < dec; to++, c++) {
                    *to = *c;
                    decIdx--;
                    if ((decIdx % 3) == 0 && decIdx > 0)*++to = ',';
                }
                while (c < end) *to++ = *c++;
                *to = '\0';
                return std::string(buf);
            }
        }
        return c;
    }
}
