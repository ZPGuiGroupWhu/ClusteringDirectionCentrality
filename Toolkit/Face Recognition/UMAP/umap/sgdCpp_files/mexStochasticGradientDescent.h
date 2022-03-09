//
// Created by conno on 2021-01-12.
//
/*
 *
   AUTHORSHIP
   Primary Developers:  Connor Meehan <connor.gw.meehan@gmail.com>
   			 Stephen Meehan <swmeehan@stanford.edu>
   Math Lead:  		 Connor Meehan <connor.gw.meehan@gmail.com>
   Provided by the Herzenberg Lab at Stanford University
   License: BSD 3 clause
*/

#ifndef SGDCPP_FILES_MEXSTOCHASTICGRADIENTDESCENT_H

#define SGDCPP_FILES_MEXSTOCHASTICGRADIENTDESCENT_H
namespace suh{
class Task {
public:
    static void Run(
        double *head_embedding,  double *tail_embedding,
        const unsigned *head, const unsigned *tail, const int n_epochs, 
        const size_t size_head_embedding, const unsigned int n_vertices,
        const double *epochs_per_sample, const double a, const double b,
        const double gamma, const double initial_alpha,
        const double negative_sample_rate, const size_t n_1_simplices,
        const size_t n_components, const bool move_other,
        const unsigned n_async_tasks,mxArray **prArgs, const int epochReports,
            const int verbose);
    void operator()();

private:
 
 class UnsharedData{
     // these data items are used by each task to calculate n_neg_samples 
     // so any race conditions in reading and writing a double 
     // (doubt it on 64 bit architecture) could lead to long loop with
     //
    double *epoch_of_next_sample,
            *epoch_of_next_negative_sample,
            *epochs_per_negative_sample;
    double  *current, *other, *sub;
    
    UnsharedData(const double *epochs_per_sample,
            const double negative_sample_rate, 
            const size_t n_1_simplices, 
            const size_t n_components);
    ~UnsharedData();
    friend Task;
};

    Task(double *const head_embedding, 
            double *const tail_embedding, 
            const unsigned int *const head,
            const unsigned int *const tail, 
            const size_t size_head_embedding,
            const unsigned int n_vertices, // AKA size_tail_embedding
            const double *const epochs_per_sample,
            const UnsharedData *tum,
            const double a, const double b, 
            const double ABNEG2,
            const double BNEG1, 
            const double BG2S, 
            const size_t n_components, 
            const bool move_other,
            const int start,
            const int end,
            const unsigned int n_async_siblings);
    
    int epoch;
    double alpha, alpha4, alphaNeg4;
    
    void initializeEpoch(
            const int epoch, 
            const double alpha, 
            const double alpha4,
            const double alphaNeg4){
        this->epoch=epoch;
        this->alpha=alpha;
        this->alpha4=alpha4;
        this->alphaNeg4=alphaNeg4;
    }
            
    void doNotMoveTail();
    void doMoveTail();

    const unsigned int n_async_siblings;
    const bool move_other;
    //const int verbose; //dare_U2_uncomment
    double *const head_embedding;
    double *const tail_embedding;
    const unsigned *const head;
    const unsigned *const tail;
    const unsigned int n_vertices;
    const double *const epochs_per_sample;
    double *const epoch_of_next_sample;
    double *const epoch_of_next_negative_sample;
    const double *const epochs_per_negative_sample;
    double *current;
    double *other;
    double *sub;
    const double a;
    const double b;
    const double ABNEG2;
    const double BNEG1;
    const double BG2S;
    const size_t n_components;
    const int start;
    const int end;
    const size_t size_head_embedding;
    //double dog_dare_U2_uncomment_this_with_MicroSoft=2;
    
};
}

#endif //SGDCPP_FILES_MEXSTOCHASTICGRADIENTDESCENT_H
