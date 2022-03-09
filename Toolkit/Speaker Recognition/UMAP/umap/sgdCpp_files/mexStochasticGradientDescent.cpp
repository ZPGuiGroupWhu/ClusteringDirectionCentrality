//
// Created by Connor on 2020-04-28.
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


#include "mex.h"
#include "mexStochasticGradientDescent.h"
#include <iostream>
#include <fstream>
#include <math.h>
#include <stdio.h>
#include <string.h>
#include <exception>
#include <vector>
#include <future>

int callProgressFcn( mxArray **args, const int epoch){
    int*epochsPtr=(int*)mxGetData(args[2]);    
    epochsPtr[0]=epoch;
    mxArray *argout[1];
    mexCallMATLAB(1, argout, 3, args, "feval");  /* Call the plotfcn function handle */
    int *continuing=(int*)mxGetPr(argout[0]);
    return continuing[0];
}

unsigned int getUnsignedInt(const mxArray *arg, const int argNum, const char *argName){
    const unsigned int value=(int)mxGetScalar(arg);
    if (!mxIsUint32(arg)){
        mexWarnMsgIdAndTxt("mexStochasticGradientDescent:int32",
                "Converted arg %d \"%s\"==%d to unsigned int 32 ...", 
                argNum, argName, value);
    }
    return value;
}

using namespace suh;

void mexFunction(int nlhs, mxArray *plhs[],
        int nrhs, const mxArray *prhs[]){
    int verbose=0;

    if (nlhs != 1){
        if (nrhs<14){
            mexErrMsgTxt("Why call if you don't listen? 0 argout and <14 argin (epochCallbackFcn)");
            return;
        }
    }
/* sanity check: ensure we have input data */
    if (nrhs != 13 && nrhs != 14 && nrhs != 15) {
        mexPrintf("Expecting 13 to 15 args NOT %d args!\n", nrhs);
        mexErrMsgTxt("Expected args: head_embedding, tail_embedding, head, tail, n_epochs, n_vertices, epochs_per_sample, a, b, gamma, initial_alpha, negative_sample_rate, randomize, @(data,epochs)fcnProgress");
        return;
    }

    if (nrhs>=14 
            && !mxIsEmpty(prhs[13]) 
            && mxFUNCTION_CLASS != mxGetClassID(prhs[13])){
        mexPrintf("\n\nNew call to mexStochasticGradientDescent!"
                 "\n\tcallback not function handle ...assuming verbose\n"); 
        verbose=1;
    }
        
    double *head_embedding, *tail_embedding;
    unsigned *head, *tail;
    double *epochs_per_sample;
    double negative_sample_rate, a, b, gamma, initial_alpha;
    const size_t n_components = (unsigned int)mxGetN(prhs[0]);
    const size_t size_head_embedding = mxGetM(prhs[0]);

    size_t cols=n_components;
    size_t rows=size_head_embedding;

    plhs[0] = mxDuplicateArray(prhs[0]);
    head_embedding = mxGetPr(plhs[0]);

    size_t size_tail_embedding = mxGetM(prhs[1]);
    if (verbose>0)
        mexPrintf("Length of tail_embedding is %d!\n", size_tail_embedding);

    mxLogical move_other = size_tail_embedding<1;
    if (verbose>0){
        mexPrintf("move_other=%d && size_tail_embedding=%d\n", move_other, size_tail_embedding);
    }
    
    unsigned int n_epochs = (int)getUnsignedInt(prhs[4], 5, "n_epochs");
    unsigned int epochReports=10;
    if (!move_other) { //template reduction (supervised or unsupervised)
        mxArray *tailEmbArray = mxDuplicateArray(prhs[1]);
        tail_embedding = mxGetPr(tailEmbArray);
        if (size_head_embedding<10001 && n_components<3) {
            epochReports=4;
        } else if (size_head_embedding<20000) {
            epochReports = 5;
        } else if (size_head_embedding<100000){
            if (n_epochs==30)
                epochReports = 6;
            else
                epochReports=10;
        }
    } else {
        tail_embedding = head_embedding;
        size_tail_embedding=size_head_embedding;
        if (size_head_embedding<8194) {
            epochReports = 5;
        } else if (size_head_embedding < 20000){
            epochReports=7;
        }else if (size_head_embedding>90000){
            epochReports = 20;
        }
    }
    const size_t size_head = (unsigned int) mxGetM(prhs[2]);
    if (mxGetClassID(prhs[2]) != mxUINT32_CLASS) {
        mexErrMsgTxt("Oh no! Head array for indexing is wrong data type!");
        return;
    }
    head = static_cast<unsigned *>(mxGetData(prhs[2]));
    
    const size_t size_tail =  mxGetM(prhs[3]);
    if (verbose>0)
        mexPrintf("Length of tail is %d!\n", size_tail);

    tail = static_cast<unsigned *>(mxGetData(prhs[3]));

    mxArray *fcnProgress=NULL, *out=NULL, *epochs=NULL;
    int *epochsPtr=NULL;
    bool haveCallback=nrhs>=14 && !mxIsEmpty(prhs[13]);
    if (haveCallback){
        if (mxFUNCTION_CLASS != mxGetClassID(prhs[13])){
            haveCallback=false;            
        } else{
            epochs=mxCreateNumericMatrix(1, 2, mxINT32_CLASS, mxREAL);
            epochsPtr=(int*)mxGetData(epochs);
            epochsPtr[1]=n_epochs;
            fcnProgress=(mxArray *) prhs[13];
            out=(mxArray *) plhs[0];
        }
    } 
    mxArray *args[3]={fcnProgress, out, epochs};
    mxArray **prArgs;
    if (haveCallback){
        prArgs=args;
    } else {
        prArgs=NULL;
    }

    unsigned int n_vertices = getUnsignedInt(prhs[5], 6, "n_vertices");
    if (verbose>0)
        mexPrintf("n_vertices is %d \n", n_vertices);
    if (move_other && size_head_embedding != n_vertices) {
        mexErrMsgTxt("Whoa! head_embedding doesn't have n_vertices rows??");
        return;
    }
    if (!move_other && size_tail_embedding != n_vertices) {
        mexErrMsgTxt("Whoa! tail_embedding doesn't have n_vertices rows??");
        return;
    }
    const size_t size_epochs_per_sample = mxGetM(prhs[6]);
    epochs_per_sample = mxGetPr(prhs[6]);

    a = mxGetScalar(prhs[7]);
    if (verbose>0)
        mexPrintf("a value is  %lf \n", a);

    b = mxGetScalar(prhs[8]);

    if (verbose>0)
        mexPrintf("b values is  %lf \n", b);

    gamma = mxGetScalar(prhs[9]);
    if (verbose>0)
        mexPrintf("gamma value is %lf \n", gamma);

    initial_alpha = mxGetScalar(prhs[10]);
    if (verbose>0)
        mexPrintf("initial_alpha values is %lf \n", initial_alpha);

    negative_sample_rate = mxGetScalar(prhs[11]);
    if (verbose>0)
        mexPrintf("negative_sample_rate value is %d \n", negative_sample_rate);
    
    unsigned int rand_seed = getUnsignedInt(prhs[12], 13, "rand_seed");
    if (verbose>0)
        mexPrintf("rand value is %d \n", rand_seed);
    
    unsigned int n_async_tasks;
    if (nrhs >= 15) {
        n_async_tasks = getUnsignedInt(prhs[14], 15, "n_async_tasks");
        if (verbose > 0)
            mexPrintf("n_async_tasks value is %d \n", n_async_tasks);
    } else {
        n_async_tasks=1;
    }    
    if (rand_seed == 0) { // do NOT randomize
        srand(rand_seed);
        if (n_async_tasks != 1){
            mexWarnMsgIdAndTxt("mexStochasticGradientDescent:argConflict",
                    "rand_seed arg >0 thus n_async_tasks is changed from %d to 1",
                    n_async_tasks);
            n_async_tasks = 1;
        }
    } else { // DO randomize 
        /* the C++ way to create a random see is documented at
           http://www.cplusplus.com/reference/cstdlib/srand/
         */
        srand ((unsigned int) time(NULL));
    }

    const size_t n_1_simplices = size_epochs_per_sample;
    Task::Run(head_embedding, tail_embedding, head, tail, n_epochs,
            size_head_embedding, n_vertices, epochs_per_sample,
            a, b, gamma, initial_alpha,
            negative_sample_rate, n_1_simplices, n_components,
            move_other, n_async_tasks, prArgs, epochReports, verbose);   
}

void Task::Run(
        double *head_embedding,  double *tail_embedding,
        const unsigned *head, const unsigned *tail, const int n_epochs, 
        const size_t  size_head_embedding, const unsigned int n_vertices,
        const double *epochs_per_sample, const double a, const double b,
        const double gamma, const double initial_alpha,
        const double negative_sample_rate, const size_t n_1_simplices,
        const size_t n_components, const bool move_other,
        const unsigned int n_async_tasks, mxArray **prArgs, 
        const int epochReports, const int verbose) {        
    double alpha = initial_alpha, alpha4=alpha*4, alphaNeg4=alpha*-4;
    const double BG2S=2*gamma*b, ABNEG2=-2.0*a*b, 
            BNEG1=b-1, nTh=(double) n_epochs/double(epochReports);
    Task::UnsharedData **tum=new Task::UnsharedData*[n_async_tasks];
    const unsigned int work= ((unsigned int) n_1_simplices) / n_async_tasks;
    std::vector<Task >tasks;
    for (unsigned int i=0;i<n_async_tasks;i++) {
        tum[i]=new Task::UnsharedData(
                epochs_per_sample, negative_sample_rate, 
                n_1_simplices, n_components);
        const unsigned int start=i*work, end = i<n_async_tasks-1?start+work:(unsigned int)n_1_simplices;
        if (verbose>0){
            if (n_async_tasks==1)
                mexPrintf("Only 1 task avoids std::async & std::future API\n");
            else
                mexPrintf("Tasks %d  from %d to %d\n", i, start, end);
        }
        tasks.push_back(Task(
                head_embedding, tail_embedding,
                head, tail, size_head_embedding, n_vertices,
                epochs_per_sample, tum[i],
                a, b, ABNEG2, BNEG1, BG2S, n_components, 
                move_other, start, end, n_async_tasks-1));
    }
    for (int n = 1;n <=n_epochs;n++) {
        std::vector<std::future<void>> futures;
        for (Task &task:tasks) {
            task.initializeEpoch(n, alpha, alpha4, alphaNeg4);
            if (n_async_tasks==1){
                task();
                break;
            }
            auto f = std::async(task);
            futures.push_back(std::move(f));
        }
        if (n_async_tasks>1){
            for (auto &f:futures){
                f.get();
            }
        }
         
        alpha = initial_alpha * (1 - static_cast<double>(static_cast<double>(n) / static_cast<double>(n_epochs)));
        alpha4 = alpha * 4;
        alphaNeg4 = alpha * -4;
        if (prArgs!=NULL){
            double nBynTh = floor(fmod((double) n, nTh));
            if (nBynTh == 0) {
                const int n_epoch = n + 1;
                if (n_epoch < n_epochs) {
                    int continuing=callProgressFcn(prArgs, n_epoch);
                    if (continuing==0){
                        break;
                    }
                }
            }
        }
    }
    for (unsigned int i=0;i<n_async_tasks;i++) {
        delete tum[i];
    }
    
}

void Task::operator()() {
    //mexPrintf("Inside thread\n");
    if (!move_other){
        doNotMoveTail();
    } else{
        doMoveTail();
    }
    // uncommenting this line causes freezing even when there is 1 task
//    mexPrintf("Leaving thread %d\n", n_async_siblings);
}


Task::UnsharedData::~UnsharedData(){
    delete []epoch_of_next_negative_sample;
    delete []epochs_per_negative_sample;
    delete []epoch_of_next_sample;
    delete []current;
    delete []other;
    delete []sub;
}

Task::UnsharedData::UnsharedData(
        const double *epochs_per_sample,
        const double negative_sample_rate,
        const size_t n_1_simplices,
        const size_t n_components){
    current=new double[n_components];
    other=new double[n_components];
    sub=new double[n_components];
    epoch_of_next_sample = new double[n_1_simplices];
    epochs_per_negative_sample = new double[n_1_simplices];
    epoch_of_next_negative_sample = new double[n_1_simplices];    
    for (int i = 0; i < n_1_simplices; i++) {
        epoch_of_next_sample[i] = epochs_per_sample[i];
        epochs_per_negative_sample[i] = epochs_per_sample[i] / negative_sample_rate;
        epoch_of_next_negative_sample[i] = epochs_per_negative_sample[i];
    }   
}

Task::Task(
        double *const head_embedding, 
        double *const tail_embedding,
        const unsigned *const head, 
        const unsigned *const tail, 
        const size_t size_head_embedding,
        const unsigned int n_vertices,
        const double *const epochs_per_sample, 
        const Task::UnsharedData *tum,
        const double a, const double b, 
        const double ABNEG2, 
        const double BNEG1, 
        const double BG2S,
        const size_t n_components, 
        const bool move_other,
        const int start, 
        const int end,
        const unsigned int n_async_siblings) :
           head_embedding(head_embedding), 
           tail_embedding(tail_embedding),
           head(head),  tail(tail), 
           size_head_embedding(size_head_embedding),
           n_vertices(n_vertices), 
           epochs_per_sample(epochs_per_sample), 
           epoch_of_next_sample(tum->epoch_of_next_sample),
           epoch_of_next_negative_sample(tum->epoch_of_next_negative_sample),
           epochs_per_negative_sample(tum->epochs_per_negative_sample),
           current(tum->current), other(tum->other), sub(tum->sub),
           a(a), b(b), ABNEG2(ABNEG2), BNEG1(BNEG1), BG2S(BG2S),
           n_components(n_components),
           move_other(move_other), start(start), end(end), 
           n_async_siblings(n_async_siblings),
           epoch(0), alpha(0.0), alpha4(0.0), alphaNeg4(0.){//,verbose(verbose){
                    
}


void Task::doMoveTail(){
    // Switch from mxMalloc and mxFree due to cautionary tales in
    // https://www.mathworks.com/matlabcentral/answers/418782-thread-safety-of-mx-mex-functions
    for (int i = start; i < end; i++) {
        if (epoch_of_next_sample[i] > epoch) {
            continue;
        }        
        const int j = head[i] - 1;//const
        int k = tail[i] - 1;
        double dist_squared = 0;
        for (int m = 0; m < n_components; m++) {
            current[m] = head_embedding[j + n_vertices * m];
            other[m] = tail_embedding[k + n_vertices * m];
            sub[m] = current[m] - other[m];
            dist_squared += sub[m] * sub[m];
        }
        if (dist_squared > 0) {
            const double grad_coef = (ABNEG2 * pow(dist_squared, BNEG1)) / (a * pow(dist_squared, b) + 1);
            for (int m = 0; m < n_components; m++) {
                const double val = grad_coef * sub[m];
                double grad;
                if (val >= 4) {
                    grad = alpha4;
                } else if (val <= -4) {
                    grad = alphaNeg4;
                } else {
                    grad = val * alpha;
                }
                current[m] = current[m] + grad;
                other[m] = other[m] - grad;
                tail_embedding[k + n_vertices * m] = other[m];
            }
        } 
        epoch_of_next_sample[i] += epochs_per_sample[i];
        const int n_neg_samples = 
          static_cast<int>(floor(
                ((static_cast<double>(epoch))
                - epoch_of_next_negative_sample[i]) /
                epochs_per_negative_sample[i]
            ));

        for (int p = 0; p < n_neg_samples; p++) {
            k = rand() % n_vertices;
            if (j == k) {
                continue;
            }
            dist_squared = 0;
            for (int m = 0; m < n_components; m++) {
                other[m] = tail_embedding[k + n_vertices * m];
                sub[m] = current[m] - other[m];
                dist_squared += sub[m] * sub[m];
            }
            if (dist_squared > 0) {
                const double grad_coef = ((BG2S / (0.001 + dist_squared))) / (a * pow(dist_squared, b) + 1);
                for (int m = 0; m < n_components; m++) {
                    const double val = grad_coef * sub[m];
                    double grad;
                    if (val >= 4) {
                        grad = alpha4;
                    } else if (val <= -4) {
                        grad = alphaNeg4;
                    } else {
                        grad = val * alpha;
                    }
                    current[m] = current[m] + grad;
                }
            } else {
                for (int m = 0; m < n_components; m++) {       
                    current[m] = current[m] + 4;
                }
            }
        }
        for (int m = 0; m < n_components; m++) {
            head_embedding[j + n_vertices * m] = current[m];
        }
        epoch_of_next_negative_sample[i] += n_neg_samples * epochs_per_negative_sample[i];
    }
}

void Task::doNotMoveTail(){
    for (int i = start; i < end; i++) {
        //if (verbose > 0 && (i==start+1 || ((i+1)%12000)==0)) mexPrintf("start=%d: %d/%d simplicial\n", start, i, end);
        if (epoch_of_next_sample[i] > epoch) {
            continue;
        }
        const int j = head[i] - 1;//const
        int k = tail[i] - 1;
        double dist_squared = 0;
        for (int m = 0; m < n_components; m++) {
            current[m] = head_embedding[j + size_head_embedding *m];
            other[m] = tail_embedding[k + n_vertices*m];
            sub[m] = current[m] - other[m];
            dist_squared += sub[m] * sub[m];
        }
        if (dist_squared > 0) {
            double grad;
            double grad_coef = (ABNEG2 * pow(dist_squared, BNEG1)) / (a * pow(dist_squared, b) + 1);
            for (int m = 0; m < n_components; m++) {
                const double val = grad_coef * sub[m];
                if (val >= 4) {
                    grad = alpha4;
                } else if (val <= -4) {
                    grad = alphaNeg4;
                } else {
                    grad = val * alpha;
                }
                current[m] = current[m] + grad;
            }
        }
        epoch_of_next_sample[i] += epochs_per_sample[i];
        double n_neg_samples = static_cast<int>(floor(((static_cast<double>(epoch))
        - epoch_of_next_negative_sample[i]) /
                epochs_per_negative_sample[i]));
        
        for (int p = 0; p < n_neg_samples; p++) {
            k = rand() % n_vertices;
            dist_squared = 0;
            for (int m = 0; m < n_components; m++) {
                other[m] = tail_embedding[k + n_vertices*m];
                sub[m] = current[m] - other[m];
                dist_squared += sub[m] * sub[m];
            }
            if (dist_squared > 0) {
                double grad_coef = ((BG2S / (0.001 + dist_squared))) / (a * pow(dist_squared, b) + 1);
                double grad;
                for (int m = 0; m < n_components; m++) {
                    const double val = grad_coef * sub[m];
                    if (val >= 4) {
                        grad = alpha4;
                    } else if (val <= -4) {
                        grad = alphaNeg4;
                    } else {
                        grad = val * alpha;
                    }
                }
            } else {
                for (int m = 0; m < n_components; m++) {
                    current[m] = current[m] + 4;
                }
            }
        }
        for (int m = 0; m < n_components; m++) {
            head_embedding[j + size_head_embedding *m] = current[m];
        }
        epoch_of_next_negative_sample[i] += n_neg_samples * epochs_per_negative_sample[i];
    }
}

